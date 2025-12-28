//
//  Directory Async Iteration Performance Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//
//  Performance benchmarks for async directory iteration.
//  Compares pull-based async iteration against sync baseline.
//
//  Note: These heavy benchmarks are skipped on Windows CI to avoid
//  resource exhaustion issues on the GitHub Actions runner.

import Clocks
import File_System_Test_Support
import Formatting
import StandardLibraryExtensions
import StandardsTestSupport
import Testing

@testable import File_System
@testable import File_System_Async

#if os(macOS) || os(Linux)

    /// Performance benchmarks for async directory iteration.
    /// Measures pull-based async iterator performance vs sync baseline.
    @Suite(.serialized)
    final class DirectoryAsyncIterationPerformanceTests2 {
        let testDir1000Files: File.Directory

        init() throws {
            let td = try File.Directory.Temporary.system

            let fileData = [UInt8](repeating: 0x00, count: 10)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)

            // Setup: 1000 files directory
            self.testDir1000Files = File.Directory(
                File.Path(
                    td.path,
                    appending: "perf_async_iter2_1000_\(Int.random(in: 0..<Int.max))"
                )
            )
            try File.System.Create.Directory.create(at: testDir1000Files.path)
            for i in 0..<1000 {
                let filePath = File.Path(testDir1000Files.path, appending: "file_\(i).txt")
                try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
            }
        }

        deinit {
            try? File.System.Delete.delete(at: testDir1000Files.path, options: .init(recursive: true))
        }

        // MARK: - Batch Size Comparison

        @Test("Batch size 64 - 1000 files × 100 loops (async)")
        func batchSize64() async throws {
            let fs = File.System.Async()
            let dir = File.Directory.Async(fs: fs)
            let loopCount = 100
            let clock = Time.Clock.Continuous()
            let start = clock.now

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 64) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = (clock.now - start).inSeconds
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 64: \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
            )
            print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await fs.shutdown()
        }

        @Test("Batch size 128 - 1000 files × 100 loops (async)")
        func batchSize128() async throws {
            let fs = File.System.Async()
            let dir = File.Directory.Async(fs: fs)
            let loopCount = 100
            let clock = Time.Clock.Continuous()
            let start = clock.now

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 128) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = (clock.now - start).inSeconds
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 128: \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
            )
            print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await fs.shutdown()
        }

        @Test("Batch size 256 - 1000 files × 100 loops (async)")
        func batchSize256() async throws {
            let fs = File.System.Async()
            let dir = File.Directory.Async(fs: fs)
            let loopCount = 100
            let clock = Time.Clock.Continuous()
            let start = clock.now

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 256) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = (clock.now - start).inSeconds
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 256: \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
            )
            print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await fs.shutdown()
        }

        // MARK: - Default Batch Size (Public API)

        @Test("Pull-based async iteration (default batch) - 1000 files × 100 loops (async)")
        func pullBasedAsyncDefaultBatch() async throws {
            let fs = File.System.Async()
            let dir = File.Directory.Async(fs: fs)
            let loopCount = 100
            let clock = Time.Clock.Continuous()
            let start = clock.now

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = (clock.now - start).inSeconds
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "PULL-BASED ASYNC (default batch): \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
            )
            print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
            print("Target: < 1000 ns/file")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await fs.shutdown()
        }

        // MARK: - Comparison with Sync Baseline

        @Test("Sync vs Async comparison - 1000 files × 100 loops (async)")
        func syncVsAsyncComparison() async throws {
            let fs = File.System.Async()
            let loopCount = 100
            let totalFiles = loopCount * 1000

            // Sync baseline
            let syncClock = Time.Clock.Continuous()
            let syncStart = syncClock.now
            for _ in 0..<loopCount {
                let (iterator, handle) = try File.Directory.Contents.makeIterator(
                    at: testDir1000Files
                )
                defer { File.Directory.Contents.closeIterator(handle) }

                var iter = iterator
                var count = 0
                while iter.next() != nil {
                    count += 1
                }
                #expect(count == 1000)
            }
            let syncElapsed = (syncClock.now - syncStart).inSeconds
            let syncPerFileNs = (syncElapsed / Double(totalFiles)) * 1_000_000_000

            // Async
            let dir = File.Directory.Async(fs: fs)
            let asyncClock = Time.Clock.Continuous()
            let asyncStart = asyncClock.now
            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files) {
                    count += 1
                }
                #expect(count == 1000)
            }
            let asyncElapsed = (asyncClock.now - asyncStart).inSeconds
            let asyncPerFileNs = (asyncElapsed / Double(totalFiles)) * 1_000_000_000

            let overhead = asyncPerFileNs / syncPerFileNs

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("SYNC vs ASYNC COMPARISON (\(totalFiles) files)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Sync:  \(syncPerFileNs.formatted(.number.precision(1))) ns/file")
            print("Async: \(asyncPerFileNs.formatted(.number.precision(1))) ns/file")
            print("Overhead: \(overhead.formatted(.number.precision(1)))×")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            await fs.shutdown()
        }
    }

#endif
