//
//  Performance Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//
//  ## Benchmark Hygiene
//
//  These tests use class-based fixtures to ensure setup/teardown runs OUTSIDE
//  the timed measurement region. This prevents file creation, executor startup,
//  and cleanup from inflating performance numbers.
//
//  Pattern:
//  - `init()` creates fixtures (files, directories, executors)
//  - `deinit` cleans up synchronously
//  - Test methods measure only the operation under test
//

import File_System_Primitives
import File_System_Test_Support
import StandardsTestSupport
import Testing
import TestingPerformance

@testable import File_System_Async

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

// Note: File.IO #TestSuites declared in Support/Test.swift

extension File.IO.Test.Performance {

    // MARK: - Executor Performance

    /// Tests executor overhead with pre-created executor.
    /// Startup latency test intentionally creates executor inside timed region.
    @Suite(.serialized)
    final class `Executor Performance`: @unchecked Sendable {
        let executor: File.IO.Executor
        let statFilePath: File.Path
        var statFd: Int32 = -1

        init() async throws {
            // Create executor ONCE, reuse across iterations
            self.executor = File.IO.Executor(File.IO.Blocking.Threads.Options(workers: 8))

            // Create a file for fstat testing (instead of Thread.sleep)
            let tempDir = try File.Directory.Temporary.system
            self.statFilePath = File.Path(
                tempDir.path,
                appending: "perf_executor_stat_\(Int.random(in: 0..<Int.max)).txt"
            )

            let data = [UInt8](repeating: 0x00, count: 100)
            try File.System.Write.Atomic.write(data.span, to: statFilePath)

            // Open FD for fstat testing
            self.statFd = open(statFilePath.string, O_RDONLY)
        }

        deinit {
            if statFd >= 0 { close(statFd) }
            try? File.System.Delete.delete(at: statFilePath)
            // Note: executor.shutdown() is async, but we're in deinit
            // The executor will clean up when deallocated
        }

        @Test(
            "Job submission throughput (1000 lightweight jobs)",
            .timed(iterations: 5, warmup: 1)
        )
        func jobSubmissionThroughput() async throws {
            // Executor already created in init
            await withTaskGroup(of: Int.self) { group in
                for i in 0..<1000 {
                    group.addTask {
                        _ = try? await self.executor.run { i * 2 }
                        return i
                    }
                }

                var count = 0
                for await _ in group {
                    count += 1
                }
                #expect(count == 1000)
            }
        }

        @Test("Sequential job execution", .timed(iterations: 20, warmup: 3))
        func sequentialJobExecution() async throws {
            // 50 sequential jobs - executor from fixture
            for i in 0..<50 {
                let result = try await executor.run { i * 2 }
                #expect(result == i * 2)
            }
        }

        @Test("Executor startup latency", .timed(iterations: 10, warmup: 2))
        func executorStartupLatency() async throws {
            // INTENTIONALLY creates executor inside timed region
            // to measure first-job latency including worker startup
            let newExecutor = File.IO.Executor()

            let result = try await newExecutor.run { 42 }
            #expect(result == 42)
            await newExecutor.shutdown()
        }

        @Test("Concurrent job completion", .timed(iterations: 5, warmup: 1))
        func concurrentJobCompletion() async throws {
            // 100 concurrent jobs with fstat syscall (not Thread.sleep)
            let fd = self.statFd
            await withTaskGroup(of: Bool.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        do {
                            return try await self.executor.run {
                                // Use fstat on fixture FD instead of Thread.sleep
                                var s = stat()
                                return fstat(fd, &s) == 0
                            }
                        } catch {
                            return false
                        }
                    }
                }

                var successCount = 0
                for await success in group {
                    if success { successCount += 1 }
                }
                #expect(successCount == 100)
            }
        }
    }

    // MARK: - Handle Store Performance

    /// Tests handle registration/destruction with pre-created file and executor.
    @Suite(.serialized)
    final class `Handle Store Performance` {
        let executor: File.IO.Executor
        let filePath: File.Path

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            self.filePath = File.Path(
                tempDir.path,
                appending: "perf_handle_\(Int.random(in: 0..<Int.max)).txt"
            )

            // Create test file with 1KB of data
            let data = [UInt8](repeating: 0x42, count: 1000)
            try File.System.Write.Atomic.write(data.span, to: filePath)
        }

        deinit {
            try? File.System.Delete.delete(at: filePath)
        }

        @Test("Handle registration and destruction", .timed(iterations: 20, warmup: 3))
        func handleRegistrationDestruction() async throws {
            // File and executor from fixture
            for _ in 0..<20 {
                let handleId = try await executor.openFile(filePath, mode: .read)
                try await executor.destroyHandle(handleId)
            }
        }

        @Test("withHandle access pattern", .timed(iterations: 20, warmup: 3))
        func withHandleAccess() async throws {
            let handleId = try await executor.openFile(filePath, mode: .read)

            // 50 withHandle accesses
            for _ in 0..<50 {
                let bytes: [UInt8] = try await executor.withHandle(handleId) { handle in
                    try handle.seek(to: 0)
                    return try handle.read(count: 100)
                }
                #expect(bytes.count == 100)
            }

            try await executor.destroyHandle(handleId)
        }
    }

    // MARK: - Directory Operations

    /// Shared fixture for async directory performance tests.
    /// Creates test directories once, reused across iterations.
    @Suite(.serialized)
    final class `Directory Operations` {
        let executor: File.IO.Executor
        let testDir100Files: File.Path
        let testDirShallowTree: File.Path
        let testDirDeepTree: File.Path

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            let fileData = [UInt8](repeating: 0x00, count: 10)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)

            // Setup: 100 files directory
            self.testDir100Files = File.Path(
                tempDir.path,
                appending: "perf_async_dir_\(Int.random(in: 0..<Int.max))"
            )
            try File.System.Create.Directory.create(at: testDir100Files)
            for i in 0..<100 {
                let filePath = File.Path(testDir100Files, appending: "file_\(i).txt")
                try File.System.Write.Atomic.write(
                    fileData.span,
                    to: filePath,
                    options: writeOptions
                )
            }

            // Setup: shallow tree (10 dirs × 10 files)
            self.testDirShallowTree = File.Path(
                tempDir.path,
                appending: "perf_walk_shallow_\(Int.random(in: 0..<Int.max))"
            )
            try File.System.Create.Directory.create(at: testDirShallowTree)
            for i in 0..<10 {
                let subDir = File.Path(testDirShallowTree, appending: "dir_\(i)")
                try File.System.Create.Directory.create(at: subDir)
                for j in 0..<10 {
                    let filePath = File.Path(subDir, appending: "file_\(j).txt")
                    try File.System.Write.Atomic.write(
                        fileData.span,
                        to: filePath,
                        options: writeOptions
                    )
                }
            }

            // Setup: deep tree (5 levels, 3 files per level)
            self.testDirDeepTree = File.Path(
                tempDir.path,
                appending: "perf_walk_deep_\(Int.random(in: 0..<Int.max))"
            )
            try File.System.Create.Directory.create(at: testDirDeepTree)
            var currentDir = testDirDeepTree
            for level in 0..<5 {
                for j in 0..<3 {
                    let filePath = File.Path(currentDir, appending: "file_\(j).txt")
                    try File.System.Write.Atomic.write(
                        fileData.span,
                        to: filePath,
                        options: writeOptions
                    )
                }
                let subDir = File.Path(currentDir, appending: "level_\(level)")
                try File.System.Create.Directory.create(at: subDir)
                currentDir = subDir
            }
            for j in 0..<3 {
                let filePath = File.Path(currentDir, appending: "file_\(j).txt")
                try File.System.Write.Atomic.write(
                    fileData.span,
                    to: filePath,
                    options: writeOptions
                )
            }
        }

        deinit {
            try? File.System.Delete.delete(at: testDir100Files, options: .init(recursive: true))
            try? File.System.Delete.delete(
                at: testDirShallowTree,
                options: .init(recursive: true)
            )
            try? File.System.Delete.delete(at: testDirDeepTree, options: .init(recursive: true))
        }

        @Test(
            "Async directory contents (100 files)",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func asyncDirectoryContents() async throws {
            let entries = try await File.Directory.Async(io: executor).contents(
                at: File.Directory(testDir100Files)
            )
            #expect(entries.count == 100)
        }

        @Test(
            "Directory entries streaming (100 files)",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func directoryEntriesStreaming() async throws {
            var count = 0
            for try await _ in File.Directory.Async(io: executor).entries(at: File.Directory(testDir100Files)) {
                count += 1
            }
            #expect(count == 100)
        }

        @Test(
            "Directory walk (shallow tree: 10 dirs × 10 files)",
            .timed(iterations: 20, warmup: 3, trackAllocations: false)
        )
        func directoryWalkShallow() async throws {
            var count = 0
            let walk = File.Directory.Async(io: executor).walk(at: File.Directory(testDirShallowTree))
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
            }
            await iterator.terminate()
            #expect(count == 110)
        }

        @Test(
            "Directory walk (deep tree: 5 levels)",
            .timed(iterations: 20, warmup: 3, trackAllocations: false)
        )
        func directoryWalkDeep() async throws {
            var count = 0
            let walk = File.Directory.Async(io: executor).walk(at: File.Directory(testDirDeepTree))
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
            }
            await iterator.terminate()
            #expect(count == 23)
        }
    }

    // MARK: - Byte Streaming

    /// Tests byte streaming with pre-created files and executor.
    @Suite(.serialized)
    final class `Byte Streaming` {
        let executor: File.IO.Executor
        let file1MB: File.Path
        let file5MB: File.Path

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            self.file1MB = File.Path(
                tempDir.path,
                appending: "perf_stream_1mb_\(Int.random(in: 0..<Int.max)).bin"
            )
            self.file5MB = File.Path(
                tempDir.path,
                appending: "perf_stream_5mb_\(Int.random(in: 0..<Int.max)).bin"
            )

            let oneMB = [UInt8](repeating: 0xAB, count: 1_000_000)
            try File.System.Write.Atomic.write(oneMB.span, to: file1MB)

            let fiveMB = [UInt8](repeating: 0xEF, count: 5_000_000)
            try File.System.Write.Atomic.write(fiveMB.span, to: file5MB)
        }

        deinit {
            try? File.System.Delete.delete(at: file1MB)
            try? File.System.Delete.delete(at: file5MB)
        }

        @Test(
            "Stream 1MB file (64KB chunks)",
            .timed(iterations: 5, warmup: 1, trackAllocations: false)
        )
        func stream1MBFile() async throws {
            let stream = File.System.Read.Async(io: executor)
            var totalBytes = 0
            for try await chunk in stream.bytes(from: file1MB) {
                totalBytes += chunk.count
            }
            #expect(totalBytes == 1_000_000)
        }

        @Test(
            "Stream 1MB file (4KB chunks)",
            .timed(iterations: 5, warmup: 1, trackAllocations: false)
        )
        func stream1MBSmallChunks() async throws {
            let stream = File.System.Read.Async(io: executor)
            let options = File.System.Read.Async.Options(chunkSize: 4096)
            var totalBytes = 0
            var chunkCount = 0
            for try await chunk in stream.bytes(from: file1MB, options: options) {
                totalBytes += chunk.count
                chunkCount += 1
            }
            #expect(totalBytes == 1_000_000)
            #expect(chunkCount > 240)
        }

        @Test("Early termination streaming", .timed(iterations: 20, warmup: 3))
        func earlyTermination() async throws {
            let stream = File.System.Read.Async(io: executor)
            var bytesRead = 0

            for try await chunk in stream.bytes(from: file5MB) {
                bytesRead += chunk.count
                if bytesRead >= 100_000 {
                    break
                }
            }

            #expect(bytesRead >= 100_000)
        }
    }

    // MARK: - Async System Operations

    /// Tests async stat/copy with pre-created files and executor.
    @Suite(.serialized)
    final class `Async System Operations` {
        let executor: File.IO.Executor
        let statFile: File.Path
        let copySource: File.Path
        let copyDestDir: File.Path

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            self.statFile = File.Path(
                tempDir.path,
                appending: "perf_async_stat_\(Int.random(in: 0..<Int.max)).txt"
            )
            self.copySource = File.Path(
                tempDir.path,
                appending: "perf_async_copy_src_\(Int.random(in: 0..<Int.max)).bin"
            )
            self.copyDestDir = File.Path(
                tempDir.path,
                appending: "perf_async_copy_dest_\(Int.random(in: 0..<Int.max))"
            )

            let statData = [UInt8](repeating: 0x00, count: 1000)
            try File.System.Write.Atomic.write(statData.span, to: statFile)

            let oneMB = [UInt8](repeating: 0xAA, count: 1_000_000)
            try File.System.Write.Atomic.write(oneMB.span, to: copySource)

            try File.System.Create.Directory.create(at: copyDestDir)
        }

        deinit {
            try? File.System.Delete.delete(at: statFile)
            try? File.System.Delete.delete(at: copySource)
            try? File.System.Delete.delete(at: copyDestDir, options: .init(recursive: true))
        }

        @Test("Async stat operations", .timed(iterations: 20, warmup: 3))
        func asyncStatOperations() async throws {
            let path = statFile
            // 50 stat operations on pre-created file
            for _ in 0..<50 {
                let exists = try await executor.run { File.System.Stat.exists(at: path) }
                #expect(exists)
            }
        }

        @Test("Async file copy (1MB)", .timed(iterations: 5, warmup: 1))
        func asyncFileCopy() async throws {
            let source = copySource
            let destPath = File.Path(
                copyDestDir,
                appending: "copy_\(Int.random(in: 0..<Int.max)).bin"
            )
            defer { try? File.System.Delete.delete(at: destPath) }

            try await executor.run { try File.System.Copy.copy(from: source, to: destPath) }

            let destExists = try await executor.run { File.System.Stat.exists(at: destPath) }
            #expect(destExists)
        }
    }

    // MARK: - Concurrency Stress

    /// Tests concurrent operations with pre-created files and executor.
    @Suite(.serialized)
    final class `Concurrency Stress`: @unchecked Sendable {
        let executor: File.IO.Executor
        let testDir: File.Path
        let filePaths: [File.Path]

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            self.testDir = File.Path(
                tempDir.path,
                appending: "perf_concurrent_\(Int.random(in: 0..<Int.max))"
            )
            try File.System.Create.Directory.create(at: testDir)

            let fileData = [UInt8](repeating: 0x55, count: 100_000)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)

            var paths: [File.Path] = []
            for i in 0..<10 {
                let filePath = File.Path(testDir, appending: "file_\(i).bin")
                try File.System.Write.Atomic.write(
                    fileData.span,
                    to: filePath,
                    options: writeOptions
                )
                paths.append(filePath)
            }
            self.filePaths = paths
        }

        deinit {
            // Synchronous cleanup - no async Task overlap
            try? File.System.Delete.delete(at: testDir, options: .init(recursive: true))
        }

        @Test(
            "Concurrent file reads (10 files)",
            .timed(iterations: 5, warmup: 1, trackAllocations: false)
        )
        func concurrentFileReads() async throws {
            // Read all files concurrently - files from fixture
            await withTaskGroup(of: Int.self) { group in
                for path in self.filePaths {
                    group.addTask {
                        do {
                            let data = try await self.executor.run {
                                try File.System.Read.Full.read(from: path)
                            }
                            return data.count
                        } catch {
                            return 0
                        }
                    }
                }

                var totalBytes = 0
                for await bytes in group {
                    totalBytes += bytes
                }
                #expect(totalBytes == 10 * 100_000)
            }
        }

        @Test("Mixed read/write operations", .timed(iterations: 5, warmup: 1))
        func mixedReadWriteOperations() async throws {
            // Concurrent writes to new files in fixture directory
            await withTaskGroup(of: Bool.self) { group in
                for i in 0..<20 {
                    group.addTask {
                        do {
                            let data = [UInt8](repeating: UInt8(i % 256), count: 10_000)
                            let filePath = File.Path(self.testDir, appending: "write_\(i).bin")
                            try await self.executor.run {
                                try File.System.Write.Atomic.write(data.span, to: filePath)
                            }
                            return true
                        } catch {
                            return false
                        }
                    }
                }

                var successCount = 0
                for await success in group {
                    if success { successCount += 1 }
                }
                #expect(successCount == 20)
            }
        }
    }

    // MARK: - Memory Tracking

    /// Tests memory behavior with pre-created files and executor.
    @Suite(.serialized)
    final class `Memory Tracking` {
        let executor: File.IO.Executor
        let testFile: File.Path
        let streamFile: File.Path

        init() async throws {
            self.executor = File.IO.Executor()

            let tempDir = try File.Directory.Temporary.system
            self.testFile = File.Path(
                tempDir.path,
                appending: "perf_mem_handle_\(Int.random(in: 0..<Int.max)).txt"
            )
            self.streamFile = File.Path(
                tempDir.path,
                appending: "perf_mem_stream_\(Int.random(in: 0..<Int.max)).bin"
            )

            let smallData = [UInt8](repeating: 0x00, count: 100)
            try File.System.Write.Atomic.write(smallData.span, to: testFile)

            let oneMB = [UInt8](repeating: 0xAB, count: 1_000_000)
            try File.System.Write.Atomic.write(oneMB.span, to: streamFile)
        }

        deinit {
            try? File.System.Delete.delete(at: testFile)
            try? File.System.Delete.delete(at: streamFile)
        }

        @Test("Executor job execution", .timed(iterations: 5))
        func executorJobExecution() async throws {
            // Run jobs using fixture executor
            for i in 0..<100 {
                let result = try await executor.run { i * 2 }
                #expect(result == i * 2)
            }
        }

        @Test(
            "Streaming doesn't accumulate memory",
            .timed(iterations: 3, maxAllocations: 5_000_000)
        )
        func streamingMemoryBounded() async throws {
            let stream = File.System.Read.Async(io: executor)

            // Stream from pre-created file
            var totalBytes = 0
            for try await chunk in stream.bytes(from: streamFile) {
                totalBytes += chunk.count
            }
            #expect(totalBytes == 1_000_000)
        }

        @Test("Handle registry cleanup", .timed(iterations: 5))
        func handleRegistryCleanup() async throws {
            // Use pre-created file from fixture
            for _ in 0..<50 {
                let handleId = try await executor.openFile(testFile, mode: .read)
                try await executor.destroyHandle(handleId)
            }
        }
    }
}
