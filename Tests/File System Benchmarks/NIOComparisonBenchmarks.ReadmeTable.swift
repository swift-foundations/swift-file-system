//
//  NIOComparisonBenchmarks.ReadmeTable.swift
//  swift-file-system
//
//  Generates a markdown table comparing swift-file-system vs NIOFileSystem performance.
//  Run with: swift test --filter ReadmeTable
//  Copy the output directly into README.md.
//

import File_System
import File_System_Async
import Foundation
import NIOCore
import Testing
import _NIOFileSystem

// MARK: - README Table Generator

extension NIOComparison.Test {

    @Suite
    struct ReadmeTable {

        struct BenchmarkResult {
            let operation: String
            let swiftTime: Double  // in seconds
            let nioTime: Double  // in seconds

            var swiftFormatted: String { formatTime(swiftTime) }
            var nioFormatted: String { formatTime(nioTime) }

            var winner: String {
                let ratio = nioTime / swiftTime
                if ratio > 1.5 {
                    return "**swift-file-system \(String(format: "%.1fx", ratio))**"
                } else if ratio < 0.67 {
                    let inverse = swiftTime / nioTime
                    return "NIO \(String(format: "%.1fx", inverse))"
                } else {
                    return "~tie"
                }
            }

            private func formatTime(_ seconds: Double) -> String {
                if seconds < 0.001 {
                    return String(format: "%.2fµs", seconds * 1_000_000)
                } else if seconds < 1.0 {
                    return String(format: "%.2fms", seconds * 1000)
                } else {
                    return String(format: "%.2fs", seconds)
                }
            }
        }

        private static func measure(
            iterations: Int = 3,
            _ block: () async throws -> Void
        ) async throws -> Double {
            // Warmup
            try await block()

            var times: [Double] = []
            for _ in 0..<iterations {
                let start = CFAbsoluteTimeGetCurrent()
                try await block()
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                times.append(elapsed)
            }
            times.sort()
            return times[times.count / 2]  // median
        }

        @Test("Generate README benchmark table")
        func generateTable() async throws {
            var results: [BenchmarkResult] = []

            // Read 100MB
            let readFixture = ReadFixture.shared
            let swiftRead = try await Self.measure {
                let bytes = try await File.System.Read.Full.read(from: readFixture.filePath)
                withExtendedLifetime(bytes.count) {}
            }
            let nioRead = try await Self.measure {
                let handle = try await FileSystem.shared.openFile(
                    forReadingAt: readFixture.nioPath,
                    options: .init()
                )
                let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(100 * 1024 * 1024))
                withExtendedLifetime(buffer.readableBytes) {}
                try await handle.close()
            }
            results.append(BenchmarkResult(operation: "Read 100MB", swiftTime: swiftRead, nioTime: nioRead))

            // Write 100MB (preallocated vs pwrite)
            let writeFixture = WriteFixture.shared
            let writeData = [UInt8](repeating: 0xCD, count: 100 * 1024 * 1024)
            let writeBuffer = ByteBuffer(bytes: writeData)

            let swiftWrite = try await Self.measure {
                let (path, _) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                let chunks: AnySequence<[UInt8]> = AnySequence([writeData])
                try File.System.Write.Streaming.write(
                    chunks,
                    to: path,
                    options: .init(commit: .direct(.init(durability: .none, expectedSize: Int64(writeData.count))))
                )
            }
            let nioWrite = try await Self.measure {
                let (path, nioPath) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                try await FileSystem.shared.withFileHandle(
                    forWritingAt: nioPath,
                    options: .newFile(replaceExisting: true)
                ) { handle in
                    try await handle.write(contentsOf: writeBuffer.readableBytesView, toAbsoluteOffset: 0)
                }
            }
            results.append(BenchmarkResult(operation: "Write 100MB", swiftTime: swiftWrite, nioTime: nioWrite))

            // Directory iteration 1000 files
            let iterFixture = DirectoryIterationFixture(name: "readme-iter", fileCount: 1000)
            let iterDir = try iterFixture.path()
            let nioIterPath = _NIOFileSystem.FilePath(iterDir.string)

            let swiftIter = try await Self.measure {
                var count = 0
                for try await _ in File.Directory.entries(at: iterDir) { count += 1 }
                withExtendedLifetime(count) {}
            }
            let nioIter = try await Self.measure {
                var count = 0
                let handle = try await FileSystem.shared.openDirectory(atPath: nioIterPath)
                for try await _ in handle.listContents() { count += 1 }
                try await handle.close()
                withExtendedLifetime(count) {}
            }
            results.append(
                BenchmarkResult(operation: "Iterate 1000 files", swiftTime: swiftIter, nioTime: nioIter)
            )

            // Copy 100MB (clone)
            let copyFixture = CopyFixture.shared

            let swiftCopy = try await Self.measure {
                let (dest, _) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }
                try await File.System.Copy.copy(from: copyFixture.sourcePath, to: dest)
            }
            let nioCopy = try await Self.measure {
                let (dest, nioDest) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }
                try await FileSystem.shared.copyItem(at: copyFixture.nioSourcePath, to: nioDest)
            }
            results.append(
                BenchmarkResult(operation: "Copy 100MB (clone)", swiftTime: swiftCopy, nioTime: nioCopy)
            )

            // Concurrent reads
            let concurrentFixture = ConcurrentReadFixture.shared

            let swiftConcurrent = try await Self.measure(iterations: 2) {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for path in concurrentFixture.paths {
                        group.addTask {
                            let bytes = try await File.System.Read.Full.read(from: path)
                            withExtendedLifetime(bytes.count) {}
                        }
                    }
                    try await group.waitForAll()
                }
            }
            let nioConcurrent = try await Self.measure(iterations: 2) {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for nioPath in concurrentFixture.nioPaths {
                        group.addTask {
                            let handle = try await FileSystem.shared.openFile(
                                forReadingAt: nioPath,
                                options: .init()
                            )
                            let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(1 * 1024 * 1024))
                            withExtendedLifetime(buffer.readableBytes) {}
                            try await handle.close()
                        }
                    }
                    try await group.waitForAll()
                }
            }
            results.append(
                BenchmarkResult(
                    operation: "100 concurrent 1MB reads",
                    swiftTime: swiftConcurrent,
                    nioTime: nioConcurrent
                )
            )

            // Generate markdown table
            print("")
            print("## Performance Comparison: swift-file-system vs NIOFileSystem")
            print("")
            print("| Operation | swift-file-system | NIOFileSystem | Winner |")
            print("|-----------|-------------------|---------------|--------|")
            for result in results {
                print(
                    "| \(result.operation) | \(result.swiftFormatted) | \(result.nioFormatted) | \(result.winner) |"
                )
            }
            print("")
            print("_Benchmarks run on Apple Silicon, hot-cache, median of 3 iterations._")
            print("")
        }
    }
}
