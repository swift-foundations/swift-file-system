//
//  EdgeCase Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Async
import File_System_Primitives

#if canImport(Foundation)
    import Foundation

    // Note: File.IO #TestSuites declared in Support/Test.swift

    extension File.IO.Test.EdgeCase {
        // MARK: - Test Fixtures

        private func createTempPath() -> String {
            "/tmp/async-edge-test-\(Int.random(in: 0..<Int.max))"
        }

        private func createTempDir() throws -> File.Path {
            let path = try File.Path(createTempPath())
            try File.System.Create.Directory.create(at: path)
            return path
        }

        private func createFile(at path: File.Path, content: [UInt8] = []) throws {
            var handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            if !content.isEmpty {
                try content.withUnsafeBufferPointer { buffer in
                    try handle.write(Span<UInt8>(_unsafeElements: buffer))
                }
            }
            try handle.close()
        }

        private func cleanup(_ path: String) {
            if let filePath = try? File.Path(path) {
                try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
            }
        }

        private func cleanupPath(_ path: File.Path) {
            try? File.System.Delete.delete(at: path, options: .init(recursive: true))
        }

        // MARK: - Executor Edge Cases

        @Test("Executor shutdown during idle")
        func executorShutdownIdle() async throws {
            let io = File.IO.Executor()
            await io.shutdown()
            // Should complete without hanging
        }

        @Test("Multiple shutdown calls are safe")
        func multipleShutdown() async throws {
            let io = File.IO.Executor()

            // Run some work first
            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }
            _ = try await io.run {
                let handle = try File.Handle.open(
                    path,
                    mode: .write,
                    options: [.create, .closeOnExec]
                )
                try handle.close()
            }

            // Multiple shutdowns should be safe
            await io.shutdown()
            await io.shutdown()
            await io.shutdown()
        }

        @Test("Work after shutdown fails gracefully")
        func workAfterShutdown() async throws {
            let io = File.IO.Executor()
            await io.shutdown()

            do {
                _ = try await io.run { 42 }
                Issue.record("Expected error after shutdown")
            } catch {
                // Expected - executor is shut down
            }
        }

        @Test("Rapid executor creation and shutdown")
        func rapidExecutorLifecycle() async throws {
            for _ in 0..<20 {
                let io = File.IO.Executor()
                _ = try await io.run { 1 + 1 }
                await io.shutdown()
            }
        }

        // MARK: - Directory Iteration Edge Cases

        @Test("Iterate directory with many files")
        func manyFiles() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create 100 files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try createFile(at: filePath)
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == 100)
            await io.shutdown()
        }

        @Test("Iterate directory that gets modified during iteration")
        func directoryModifiedDuringIteration() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create initial files
            for i in 0..<10 {
                let filePath = try File.Path("\(dir.string)/initial-\(i).txt")
                try createFile(at: filePath)
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()
            do {
                while let entry = try await iterator.next() {
                    count += 1
                    // Add new files during iteration (may or may not be seen)
                    if count == 5 {
                        let newPath = try File.Path(
                            "\(dir.string)/added-during-\(Int.random(in: 0..<Int.max)).txt"
                        )
                        try createFile(at: newPath)
                    }
                    _ = entry
                }
                await iterator.terminate()
            } catch {
                await iterator.terminate()
                throw error
            }

            // Should have iterated at least the original 10
            #expect(count >= 10)
            await io.shutdown()
        }

        @Test("Iterate empty directory")
        func emptyDirectory() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == 0)
            await io.shutdown()
        }

        @Test("Break from iteration early")
        func breakEarly() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create many files
            for i in 0..<50 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try createFile(at: filePath)
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()
            while let _ = try await iterator.next() {
                count += 1
                if count >= 5 {
                    break
                }
            }
            await iterator.terminate()

            #expect(count == 5)
            await io.shutdown()
        }

        @Test("Multiple iterators on same directory")
        func multipleIterators() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create files
            for i in 0..<20 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try createFile(at: filePath)
            }

            // Run two iterations concurrently using TaskGroup with proper cleanup
            let counts = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { group in
                for _ in 0..<2 {
                    group.addTask {
                        var c = 0
                        let entries = File.Directory.Async(io: io).entries(at: dir)
                        let iterator = entries.makeAsyncIterator()
                        do {
                            while let _ = try await iterator.next() { c += 1 }
                            await iterator.terminate()
                        } catch {
                            await iterator.terminate()
                            throw error
                        }
                        return c
                    }
                }
                var results: [Int] = []
                for try await count in group {
                    results.append(count)
                }
                return results
            }

            #expect(counts.count == 2)
            for count in counts {
                #expect(count == 20)
            }
            await io.shutdown()
        }

        // MARK: - Walk Edge Cases

        @Test("Walk deeply nested directory")
        func walkDeeplyNested() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create 10 levels of nesting
            var currentPath = root
            for i in 0..<10 {
                let subPath = try File.Path("\(currentPath.string)/level-\(i)")
                try FileManager.default.createDirectory(
                    atPath: subPath.string,
                    withIntermediateDirectories: true
                )
                // Add a file at each level
                let filePath = try File.Path("\(subPath.string)/file.txt")
                try createFile(at: filePath)
                currentPath = subPath
            }

            var count = 0
            let walk = File.Directory.Async(io: io).walk(at: root)
            let iterator = walk.makeAsyncIterator()
            while let _ = try await iterator.next() {
                count += 1
            }
            await iterator.terminate()

            // 10 directories + 10 files = 20 entries
            #expect(count == 20)
            await io.shutdown()
        }

        @Test("Walk with symlink cycle - followSymlinks=false")
        func walkSymlinkCycleNoFollow() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create subdirectory
            let subPath = try File.Path("\(root.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to parent (cycle)
            let linkPath = try File.Path("\(subPath.string)/parent-link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: root)

            // Walk without following symlinks - should complete fine
            var count = 0
            let walk = File.Directory.Async(io: io).walk(
                at: root,
                options: .init(followSymlinks: false)
            )
            let iterator = walk.makeAsyncIterator()
            while let _ = try await iterator.next() {
                count += 1
            }
            await iterator.terminate()

            // Should see: subdir + parent-link = 2
            #expect(count == 2)
            await io.shutdown()
        }

        @Test("Walk with symlink cycle - followSymlinks=true detects cycle")
        func walkSymlinkCycleWithFollow() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create subdirectory
            let subPath = try File.Path("\(root.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to parent (cycle)
            let linkPath = try File.Path("\(subPath.string)/parent-link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: root)

            // Create a file so we can verify walk works
            let filePath = try File.Path("\(root.string)/file.txt")
            try createFile(at: filePath)

            // Walk with following symlinks - cycle detection should prevent infinite loop
            var count = 0
            let walk = File.Directory.Async(io: io).walk(at: root, options: .init(followSymlinks: true))
            let iterator = walk.makeAsyncIterator()
            while let _ = try await iterator.next() {
                count += 1
                // Safety valve - if cycle detection fails, abort
                if count > 100 {
                    Issue.record("Cycle detection failed - infinite loop detected")
                    break
                }
            }
            await iterator.terminate()

            // Should complete without infinite loop
            #expect(count <= 10)  // Reasonable upper bound
            await io.shutdown()
        }

        @Test("Walk non-existent directory fails")
        func walkNonExistent() async throws {
            let io = File.IO.Executor()

            let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

            let walk = File.Directory.Async(io: io).walk(at: path)
            let iterator = walk.makeAsyncIterator()

            do {
                while let _ = try await iterator.next() {
                    Issue.record("Should not yield anything")
                }
                Issue.record("Should have thrown error")
            } catch {
                // Expected - directory doesn't exist
                await iterator.terminate()
            }

            await io.shutdown()
        }

        @Test("Walk directory with mixed file types")
        func walkMixedTypes() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create regular file
            let filePath = try File.Path("\(root.string)/file.txt")
            try createFile(at: filePath)

            // Create subdirectory
            let subPath = try File.Path("\(root.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to file
            let linkPath = try File.Path("\(root.string)/link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: filePath)

            // Create file in subdir
            let subFilePath = try File.Path("\(subPath.string)/nested.txt")
            try createFile(at: subFilePath)

            var paths: [String] = []
            let walk = File.Directory.Async(io: io).walk(at: root)
            let iterator = walk.makeAsyncIterator()
            while let path = try await iterator.next() {
                if let component = path.lastComponent {
                    paths.append(component.string)
                }
            }
            await iterator.terminate()

            #expect(paths.count == 4)
            #expect(paths.contains("file.txt"))
            #expect(paths.contains("subdir"))
            #expect(paths.contains("link"))
            #expect(paths.contains("nested.txt"))
            await io.shutdown()
        }

        // MARK: - Byte Stream Edge Cases

        @Test("Stream empty file")
        func streamEmptyFile() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            try createFile(at: path)

            var chunks: [[UInt8]] = []
            let stream = File.Stream.Async(io: io).bytes(from: path)
            for try await chunk in stream {
                chunks.append(chunk)
            }

            #expect(chunks.isEmpty)
            await io.shutdown()
        }

        @Test("Stream file smaller than chunk size")
        func streamSmallFile() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            let data: [UInt8] = [1, 2, 3, 4, 5]
            try createFile(at: path, content: data)

            var allBytes: [UInt8] = []
            let stream = File.Stream.Async(io: io).bytes(
                from: path,
                options: .init(chunkSize: 1024)
            )
            for try await chunk in stream {
                allBytes.append(contentsOf: chunk)
            }

            #expect(allBytes == data)
            await io.shutdown()
        }

        @Test("Stream file with very small chunk size")
        func streamTinyChunks() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            let data: [UInt8] = Array(0..<100)
            try createFile(at: path, content: data)

            var chunkCount = 0
            var allBytes: [UInt8] = []
            let stream = File.Stream.Async(io: io).bytes(from: path, options: .init(chunkSize: 1))
            for try await chunk in stream {
                chunkCount += 1
                allBytes.append(contentsOf: chunk)
            }

            #expect(chunkCount == 100)
            #expect(allBytes == data)
            await io.shutdown()
        }

        @Test("Stream non-existent file fails")
        func streamNonExistent() async throws {
            let io = File.IO.Executor()

            let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

            let stream = File.Stream.Async(io: io).bytes(from: path)
            let iterator = stream.makeAsyncIterator()

            do {
                while let _ = try await iterator.next() {
                    Issue.record("Should not yield anything")
                }
                Issue.record("Should have thrown error")
            } catch {
                // Expected - file doesn't exist
                await iterator.terminate()
            }

            await io.shutdown()
        }

        @Test("Break from stream early")
        func breakFromStreamEarly() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            // Create larger file
            let data: [UInt8] = Array(repeating: 42, count: 10000)
            try createFile(at: path, content: data)

            var bytesRead = 0
            let stream = File.Stream.Async(io: io).bytes(from: path, options: .init(chunkSize: 100))
            let iterator = stream.makeAsyncIterator()
            while let chunk = try await iterator.next() {
                bytesRead += chunk.count
                if bytesRead >= 500 {
                    break
                }
            }
            await iterator.terminate()

            #expect(bytesRead >= 500)
            #expect(bytesRead < 10000)
            await io.shutdown()
        }

        // MARK: - Cancellation Edge Cases

        @Test("Cancel during directory iteration")
        func cancelDuringIteration() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create many files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try createFile(at: filePath)
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while let _ = try await iterator.next() {
                        count += 1
                        try Task.checkCancellation()
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it a moment to start, then cancel
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()

            do {
                _ = try await task.value
                // May complete before cancellation
            } catch is CancellationError {
                // Expected
            }

            await io.shutdown()
        }

        @Test("Cancel during walk")
        func cancelDuringWalk() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create some structure
            for i in 0..<5 {
                let subPath = try File.Path("\(root.string)/dir-\(i)")
                try FileManager.default.createDirectory(
                    atPath: subPath.string,
                    withIntermediateDirectories: true
                )
                for j in 0..<10 {
                    let filePath = try File.Path("\(subPath.string)/file-\(j).txt")
                    try createFile(at: filePath)
                }
            }

            let task = Task {
                var count = 0
                let walk = File.Directory.Async(io: io).walk(at: root)
                let iterator = walk.makeAsyncIterator()
                do {
                    while let _ = try await iterator.next() {
                        count += 1
                        try Task.checkCancellation()
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it a moment to start, then cancel
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()

            do {
                _ = try await task.value
            } catch is CancellationError {
                // Expected
            }

            await io.shutdown()
        }

        @Test("Cancellation within batch - directory entries")
        func cancellationWithinBatch() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create enough files to span multiple batches (batchSize = 64)
            // Create 200 files to ensure we're mid-batch when we cancel
            for i in 0..<200 {
                let filePath = try File.Path("\(dir.string)/file-\(String(format: "%03d", i)).txt")
                try createFile(at: filePath)
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while let _ = try await iterator.next() {
                        count += 1
                        // Cancel after processing 70 entries (which should be in the middle of second batch)
                        if count == 70 {
                            try Task.checkCancellation()
                        }
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it time to process first batch, then cancel during second batch
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()

            do {
                let count = try await task.value
                // If it completes, it processed everything before cancellation
                #expect(count <= 200)
            } catch is CancellationError {
                // Expected - cancellation was checked and honored
            }

            await io.shutdown()
        }

        @Test("Cancellation within batch - directory walk")
        func cancellationWithinBatchWalk() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create structure with enough entries to span multiple batches
            for i in 0..<10 {
                let subPath = try File.Path("\(root.string)/dir-\(i)")
                try FileManager.default.createDirectory(
                    atPath: subPath.string,
                    withIntermediateDirectories: true
                )
                // 20 files per directory = 200 files + 10 dirs = 210 entries total
                for j in 0..<20 {
                    let filePath = try File.Path("\(subPath.string)/file-\(j).txt")
                    try createFile(at: filePath)
                }
            }

            let task = Task {
                var count = 0
                let walk = File.Directory.Async(io: io).walk(at: root)
                let iterator = walk.makeAsyncIterator()
                do {
                    while let _ = try await iterator.next() {
                        count += 1
                        // Cancel after 100 entries (mid-iteration)
                        if count == 100 {
                            try Task.checkCancellation()
                        }
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it time to start walking, then cancel
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()

            do {
                let count = try await task.value
                #expect(count <= 210)
            } catch is CancellationError {
                // Expected
            }

            await io.shutdown()
        }

        // MARK: - Backpressure Edge Cases

        @Test("Backpressure respected with slow consumer")
        func backpressureRespectedSlowConsumer() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create many files to test backpressure
            for i in 0..<500 {
                let filePath = try File.Path("\(dir.string)/file-\(String(format: "%04d", i)).txt")
                try createFile(at: filePath)
            }

            var processedCount = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()

            // Consume slowly to verify producer doesn't accumulate unbounded batches
            do {
                while let _ = try await iterator.next() {
                    processedCount += 1
                    // Add delay to simulate slow consumer
                    try await Task.sleep(for: .milliseconds(1))
                }
                await iterator.terminate()
            } catch {
                await iterator.terminate()
                throw error
            }

            // Should process all files despite slow consumption
            #expect(processedCount == 500)
            // If backpressure wasn't working, memory would grow unboundedly
            // The AsyncThrowingChannel with 1-element buffer ensures bounded memory
            await io.shutdown()
        }

        @Test("Large directory iteration completes - 1000+ files")
        func largeDirectoryIteration() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create 1500 files to verify batching works correctly with large directories
            let fileCount = 1500
            for i in 0..<fileCount {
                let filePath = try File.Path("\(dir.string)/file-\(String(format: "%04d", i)).txt")
                try createFile(at: filePath)
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == fileCount)
            await io.shutdown()
        }

        @Test("Large walk completes - 1000+ entries")
        func largeWalkIteration() async throws {
            let io = File.IO.Executor()

            let root = try createTempDir()
            defer { cleanupPath(root) }

            // Create structure with 1000+ entries
            // 25 directories with 40 files each = 1000 files + 25 dirs = 1025 entries
            for i in 0..<25 {
                let subPath = try File.Path("\(root.string)/dir-\(String(format: "%02d", i))")
                try FileManager.default.createDirectory(
                    atPath: subPath.string,
                    withIntermediateDirectories: true
                )
                for j in 0..<40 {
                    let filePath = try File.Path(
                        "\(subPath.string)/file-\(String(format: "%02d", j)).txt"
                    )
                    try createFile(at: filePath)
                }
            }

            var count = 0
            let walk = File.Directory.Async(io: io).walk(at: root)
            let iterator = walk.makeAsyncIterator()
            while let _ = try await iterator.next() {
                count += 1
            }
            await iterator.terminate()

            #expect(count == 1025)
            await io.shutdown()
        }

        @Test("Directory deleted during iteration")
        func directoryDeletedDuringIteration() async throws {
            let io = File.IO.Executor()

            let dir = try createTempDir()
            defer { cleanupPath(dir) }

            // Create files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try createFile(at: filePath)
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while let _ = try await iterator.next() {
                        count += 1
                        // Small delay to allow deletion to happen
                        try await Task.sleep(for: .milliseconds(1))
                    }
                    await iterator.terminate()
                } catch {
                    // May throw error if directory structure changes during iteration
                    // This is acceptable behavior
                    await iterator.terminate()
                }
                return count
            }

            // Give it time to start iterating
            try await Task.sleep(for: .milliseconds(10))

            // Delete some files during iteration
            for i in 50..<75 {
                let filePath = try File.Path("\(dir.string)/file-\(i).txt")
                try? FileManager.default.removeItem(atPath: filePath.string)
            }

            let count = await task.value
            // Count may vary depending on timing of deletion
            // Just verify it doesn't crash or hang
            #expect(count >= 0)
            #expect(count <= 100)
            await io.shutdown()
        }

        // MARK: - Handle Edge Cases

        @Test("Async handle double close")
        func asyncHandleDoubleClose() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            let handle = try await File.Handle.Async.open(
                path,
                mode: .write,
                options: [.create, .closeOnExec],
                io: io
            )

            try await handle.close()
            // Second close should be safe
            try await handle.close()
            await io.shutdown()
        }

        @Test("Read from async handle after close fails")
        func readAfterClose() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            let data: [UInt8] = [1, 2, 3, 4, 5]
            try createFile(at: path, content: data)

            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

            try await handle.close()

            do {
                _ = try await handle.read(count: 5)
                Issue.record("Should have thrown")
            } catch {
                // Expected
            }
            await io.shutdown()
        }

        // MARK: - System Operation Edge Cases

        @Test("Async exists on non-existent path")
        func asyncExistsNonExistent() async throws {
            let io = File.IO.Executor()

            let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

            let exists = try await io.run { File.System.Stat.exists(at: path) }

            #expect(!exists)
            await io.shutdown()
        }

        @Test("Async stat on symlink")
        func asyncStatSymlink() async throws {
            let io = File.IO.Executor()

            let target = try File.Path(createTempPath() + ".target")
            let link = try File.Path(createTempPath() + ".link")
            defer {
                cleanupPath(target)
                cleanupPath(link)
            }

            try createFile(at: target, content: [1, 2, 3])
            try File.System.Link.Symbolic.create(at: link, pointingTo: target)

            let info = try await io.run { try File.System.Stat.info(at: link) }

            // stat follows symlinks
            #expect(info.type == .regular)
            #expect(info.size == 3)
            await io.shutdown()
        }

        // MARK: - Concurrent Operations

        @Test("Many concurrent file operations")
        func manyConcurrentOps() async throws {
            let io = File.IO.Executor()

            let basePath = createTempPath()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<50 {
                    group.addTask {
                        let path = try File.Path("\(basePath)-\(i)")
                        defer { try? File.System.Delete.delete(at: path) }

                        var handle = try File.Handle.open(
                            path,
                            mode: .write,
                            options: [.create, .closeOnExec]
                        )
                        let data: [UInt8] = Array(repeating: UInt8(i & 0xFF), count: 100)
                        try data.withUnsafeBufferPointer { buffer in
                            try handle.write(Span<UInt8>(_unsafeElements: buffer))
                        }
                        try handle.close()

                        let info = try File.System.Stat.info(at: path)
                        #expect(info.size == 100)
                    }
                }

                try await group.waitForAll()
            }
            await io.shutdown()
        }

        @Test("Concurrent reads of same file")
        func concurrentReadsOfSameFile() async throws {
            let io = File.IO.Executor()

            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            // Create file with known content
            let data: [UInt8] = Array(0..<255)
            try createFile(at: path, content: data)

            // Read concurrently
            try await withThrowingTaskGroup(of: [UInt8].self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        var allBytes: [UInt8] = []
                        let stream = File.Stream.Async(io: io).bytes(from: path)
                        for try await chunk in stream {
                            allBytes.append(contentsOf: chunk)
                        }
                        return allBytes
                    }
                }

                for try await result in group {
                    #expect(result == data)
                }
            }
            await io.shutdown()
        }

    }

#endif
