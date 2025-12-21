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
            warmup: Int = 1,
            _ block: () async throws -> Void
        ) async throws -> Double {
            // Warmup
            for _ in 0..<warmup {
                try await block()
            }

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

            // ═══════════════════════════════════════════════════════════════
            // MARK: Read Benchmarks
            // ═══════════════════════════════════════════════════════════════

            let readFixture = ReadFixture.shared

            // Read 100MB (full file)
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
            results.append(BenchmarkResult(
                operation: "Read 100MB",
                swiftTime: swiftRead,
                nioTime: nioRead
            ))

            // ═══════════════════════════════════════════════════════════════
            // MARK: Write Benchmarks
            // ═══════════════════════════════════════════════════════════════

            let writeFixture = WriteFixture.shared
            let fileSize = 100 * 1024 * 1024

            // Pre-allocate data with page touching
            let writeData: [UInt8] = {
                var d = [UInt8](repeating: 0xCD, count: fileSize)
                let pageSize = 16384
                for i in stride(from: 0, to: fileSize, by: pageSize) {
                    _ = d[i]
                }
                return d
            }()
            let writeBuffer = ByteBuffer(bytes: writeData)

            // Write 100MB (single buffer, preallocated)
            let swiftWriteSingle = try await Self.measure {
                let (path, _) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                let chunks: AnySequence<[UInt8]> = AnySequence([writeData])
                try File.System.Write.Streaming.write(
                    chunks,
                    to: path,
                    options: .init(commit: .direct(.init(
                        durability: .none,
                        expectedSize: Int64(fileSize)
                    )))
                )
            }
            let nioWriteSingle = try await Self.measure {
                let (path, nioPath) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                try await FileSystem.shared.withFileHandle(
                    forWritingAt: nioPath,
                    options: .newFile(replaceExisting: true)
                ) { handle in
                    try await handle.write(
                        contentsOf: writeBuffer.readableBytesView,
                        toAbsoluteOffset: 0
                    )
                }
            }
            results.append(BenchmarkResult(
                operation: "Write 100MB (single buffer)",
                swiftTime: swiftWriteSingle,
                nioTime: nioWriteSingle
            ))

            // Write 100MB streaming (1MB chunks)
            let chunkSize = 1024 * 1024
            let chunkCount = fileSize / chunkSize

            let swiftWriteStreaming = try await Self.measure {
                let (path, _) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                let lazyChunks = (0..<chunkCount).lazy.map { _ in
                    [UInt8](repeating: 0xCD, count: chunkSize)
                }
                try File.System.Write.Streaming.write(
                    lazyChunks,
                    to: path,
                    options: .init(commit: .direct(.init(durability: .none)))
                )
            }
            let nioWriteStreaming = try await Self.measure {
                let (path, nioPath) = writeFixture.uniquePath()
                defer { try? File.System.Delete.delete(at: path) }
                try await FileSystem.shared.withFileHandle(
                    forWritingAt: nioPath,
                    options: .newFile(replaceExisting: true)
                ) { handle in
                    var offset: Int64 = 0
                    for _ in 0..<chunkCount {
                        let chunk = [UInt8](repeating: 0xCD, count: chunkSize)
                        let buffer = ByteBuffer(bytes: chunk)
                        try await handle.write(
                            contentsOf: buffer.readableBytesView,
                            toAbsoluteOffset: offset
                        )
                        offset += Int64(chunkSize)
                    }
                }
            }
            results.append(BenchmarkResult(
                operation: "Write 100MB (streaming)",
                swiftTime: swiftWriteStreaming,
                nioTime: nioWriteStreaming
            ))

            // ═══════════════════════════════════════════════════════════════
            // MARK: Directory Iteration Benchmarks
            // ═══════════════════════════════════════════════════════════════

            // Iterate 100 files
            let iter100Fixture = DirectoryIterationFixture(name: "readme-iter-100", fileCount: 100)
            let iter100Dir = try iter100Fixture.path()
            let nioIter100Path = _NIOFileSystem.FilePath(iter100Dir.string)

            let swiftIter100 = try await Self.measure(iterations: 5) {
                var count = 0
                for try await _ in File.Directory.entries(at: iter100Dir) { count += 1 }
                withExtendedLifetime(count) {}
            }
            let nioIter100 = try await Self.measure(iterations: 5) {
                var count = 0
                let handle = try await FileSystem.shared.openDirectory(atPath: nioIter100Path)
                for try await _ in handle.listContents() { count += 1 }
                try await handle.close()
                withExtendedLifetime(count) {}
            }
            results.append(BenchmarkResult(
                operation: "Iterate 100 files",
                swiftTime: swiftIter100,
                nioTime: nioIter100
            ))

            // Iterate 1000 files
            let iter1000Fixture = DirectoryIterationFixture(name: "readme-iter-1000", fileCount: 1000)
            let iter1000Dir = try iter1000Fixture.path()
            let nioIter1000Path = _NIOFileSystem.FilePath(iter1000Dir.string)

            let swiftIter1000 = try await Self.measure {
                var count = 0
                for try await _ in File.Directory.entries(at: iter1000Dir) { count += 1 }
                withExtendedLifetime(count) {}
            }
            let nioIter1000 = try await Self.measure {
                var count = 0
                let handle = try await FileSystem.shared.openDirectory(atPath: nioIter1000Path)
                for try await _ in handle.listContents() { count += 1 }
                try await handle.close()
                withExtendedLifetime(count) {}
            }
            results.append(BenchmarkResult(
                operation: "Iterate 1000 files",
                swiftTime: swiftIter1000,
                nioTime: nioIter1000
            ))

            // ═══════════════════════════════════════════════════════════════
            // MARK: Copy Benchmarks
            // ═══════════════════════════════════════════════════════════════

            let copyFixture = CopyFixture.shared

            // Copy 100MB (APFS clone)
            let swiftCopyClone = try await Self.measure {
                let (dest, _) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }
                try await File.System.Copy.copy(from: copyFixture.sourcePath, to: dest)
            }
            let nioCopyClone = try await Self.measure {
                let (dest, nioDest) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }
                try await FileSystem.shared.copyItem(at: copyFixture.nioSourcePath, to: nioDest)
            }
            results.append(BenchmarkResult(
                operation: "Copy 100MB (APFS clone)",
                swiftTime: swiftCopyClone,
                nioTime: nioCopyClone
            ))

            // Copy 100MB (byte-by-byte loop)
            let copyChunkSize = 64 * 1024

            let swiftCopyBytes = try await Self.measure {
                let (dest, _) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }
                try await File.System.Copy.copy(
                    from: copyFixture.sourcePath,
                    to: dest,
                    options: .init(copyAttributes: false)
                )
            }
            let nioCopyBytes = try await Self.measure {
                let (dest, nioDest) = copyFixture.uniqueDestPath()
                defer { try? File.System.Delete.delete(at: dest) }

                let readHandle = try await FileSystem.shared.openFile(
                    forReadingAt: copyFixture.nioSourcePath,
                    options: .init()
                )

                do {
                    try await FileSystem.shared.withFileHandle(
                        forWritingAt: nioDest,
                        options: .newFile(replaceExisting: true)
                    ) { writeHandle in
                        var offset: Int64 = 0
                        while true {
                            let buffer = try await readHandle.readChunk(
                                fromAbsoluteOffset: offset,
                                length: .bytes(Int64(copyChunkSize))
                            )
                            if buffer.readableBytes == 0 { break }

                            try await writeHandle.write(
                                contentsOf: buffer.readableBytesView,
                                toAbsoluteOffset: offset
                            )
                            offset += Int64(buffer.readableBytes)
                        }
                    }
                    try await readHandle.close()
                } catch {
                    try? await readHandle.close()
                    throw error
                }
            }
            results.append(BenchmarkResult(
                operation: "Copy 100MB (byte loop)",
                swiftTime: swiftCopyBytes,
                nioTime: nioCopyBytes
            ))

            // ═══════════════════════════════════════════════════════════════
            // MARK: Concurrent Benchmarks
            // ═══════════════════════════════════════════════════════════════

            let concurrentFixture = ConcurrentReadFixture.shared

            // 100 concurrent 1MB reads
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
                            let buffer = try await handle.readToEnd(
                                maximumSizeAllowed: .bytes(1 * 1024 * 1024)
                            )
                            withExtendedLifetime(buffer.readableBytes) {}
                            try await handle.close()
                        }
                    }
                    try await group.waitForAll()
                }
            }
            results.append(BenchmarkResult(
                operation: "100 concurrent 1MB reads",
                swiftTime: swiftConcurrent,
                nioTime: nioConcurrent
            ))

            // ═══════════════════════════════════════════════════════════════
            // MARK: Output
            // ═══════════════════════════════════════════════════════════════

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
