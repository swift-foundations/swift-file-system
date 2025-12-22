//
//  Directory Async Iteration Performance Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//
//  Performance benchmarks for async directory iteration.
//  Compares pull-based async iteration against sync baseline.

import StandardsTestSupport
import Testing

@testable import File_System
@testable import File_System_Async

#if canImport(Foundation)
    import Foundation

    /// Performance benchmarks for async directory iteration.
    /// Measures pull-based async iterator performance vs sync baseline.
    @Suite(.serialized)
    final class DirectoryAsyncIterationPerformanceTests {
        let testDir1000Files: File.Path
        let io: File.IO.Executor

        init() throws {
            #if canImport(Foundation)
                let tempDir = try File.Path(NSTemporaryDirectory())
            #else
                let tempDir = try File.Path("/tmp")
            #endif

            let fileData = [UInt8](repeating: 0x00, count: 10)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)

            // Setup: 1000 files directory
            self.testDir1000Files = File.Path(
                tempDir,
                appending: "perf_async_iter_1000_\(Int.random(in: 0..<Int.max))"
            )
            try File.System.Create.Directory.create(at: testDir1000Files)
            for i in 0..<1000 {
                let filePath = File.Path(testDir1000Files, appending: "file_\(i).txt")
                try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
            }

            self.io = File.IO.Executor()
        }

        deinit {
            Task { [io] in await io.shutdown() }
            try? File.System.Delete.delete(at: testDir1000Files, options: .init(recursive: true))
        }

        // MARK: - Batch Size Comparison

        @Test("Batch size 64 - 1000 files × 100 loops")
        func batchSize64() async throws {
            let dir = File.Directory.Async(io: io)
            let loopCount = 100
            let start = Date().timeIntervalSinceReferenceDate

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 64) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = Date().timeIntervalSinceReferenceDate - start
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 64: \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms"
            )
            print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        @Test("Batch size 128 - 1000 files × 100 loops")
        func batchSize128() async throws {
            let dir = File.Directory.Async(io: io)
            let loopCount = 100
            let start = Date().timeIntervalSinceReferenceDate

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 128) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = Date().timeIntervalSinceReferenceDate - start
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 128: \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms"
            )
            print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        @Test("Batch size 256 - 1000 files × 100 loops")
        func batchSize256() async throws {
            let dir = File.Directory.Async(io: io)
            let loopCount = 100
            let start = Date().timeIntervalSinceReferenceDate

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files, batchSize: 256) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = Date().timeIntervalSinceReferenceDate - start
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "ASYNC BATCH 256: \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms"
            )
            print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        // MARK: - Default Batch Size (Public API)

        @Test("Pull-based async iteration (default batch) - 1000 files × 100 loops")
        func pullBasedAsyncDefaultBatch() async throws {
            let dir = File.Directory.Async(io: io)
            let loopCount = 100
            let start = Date().timeIntervalSinceReferenceDate

            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files) {
                    count += 1
                }
                #expect(count == 1000)
            }

            let elapsed = Date().timeIntervalSinceReferenceDate - start
            let totalFiles = loopCount * 1000
            let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(
                "PULL-BASED ASYNC (default batch): \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms"
            )
            print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
            print("Target: < 1000 ns/file")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        // MARK: - Comparison with Sync Baseline

        @Test("Sync vs Async comparison - 1000 files × 100 loops")
        func syncVsAsyncComparison() async throws {
            let loopCount = 100
            let totalFiles = loopCount * 1000

            // Sync baseline
            let syncStart = Date().timeIntervalSinceReferenceDate
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
            let syncElapsed = Date().timeIntervalSinceReferenceDate - syncStart
            let syncPerFileNs = (syncElapsed / Double(totalFiles)) * 1_000_000_000

            // Async
            let dir = File.Directory.Async(io: io)
            let asyncStart = Date().timeIntervalSinceReferenceDate
            for _ in 0..<loopCount {
                var count = 0
                for try await _ in dir.entries(at: testDir1000Files) {
                    count += 1
                }
                #expect(count == 1000)
            }
            let asyncElapsed = Date().timeIntervalSinceReferenceDate - asyncStart
            let asyncPerFileNs = (asyncElapsed / Double(totalFiles)) * 1_000_000_000

            let overhead = asyncPerFileNs / syncPerFileNs

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("SYNC vs ASYNC COMPARISON (\(totalFiles) files)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("Sync:  \(String(format: "%.1f", syncPerFileNs)) ns/file")
            print("Async: \(String(format: "%.1f", asyncPerFileNs)) ns/file")
            print("Overhead: \(String(format: "%.1f", overhead))×")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }

#endif
