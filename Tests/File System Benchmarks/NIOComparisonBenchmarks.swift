//
//  NIOComparisonBenchmarks.swift
//  swift-file-system
//
//  Benchmarks comparing swift-file-system vs NIOFileSystem performance.
//
//  Fairness rules:
//  - Setup (file creation) is outside timed regions
//  - Both use same pre-allocated data or same lazy generation
//  - Both use direct/no-fsync mode (matched durability)
//  - All pages pre-touched to avoid page fault overhead
//

import Foundation
import NIOCore
import StandardsTestSupport
import Testing

@testable import File_System
@testable import File_System_Async
import _NIOFileSystem

// MARK: - Benchmark Type

enum NIOComparison {
    #TestSuites
}

// MARK: - Shared Fixtures

/// Fixture for read benchmarks - file created ONCE, reused across iterations
final class ReadFixture: @unchecked Sendable {
    let dir: File.Path
    let filePath: File.Path
    let nioPath: _NIOFileSystem.FilePath

    static let shared: ReadFixture = {
        let fileSize = 100 * 1024 * 1024
        let dir = try! File.Path("/tmp/nio-benchmark-read-fixture")

        // Clean up any previous run
        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try! File.System.Create.Directory.create(at: dir)

        let filePath = dir.appending("large-read.bin")

        // Create file with DIRECT write (no fsync overhead in setup)
        let data = [UInt8](repeating: 0xAB, count: fileSize)
        try! File.System.Write.Streaming.write([data], to: filePath, options: .init(commit: .direct()))

        return ReadFixture(dir: dir, filePath: filePath)
    }()

    private init(dir: File.Path, filePath: File.Path) {
        self.dir = dir
        self.filePath = filePath
        self.nioPath = _NIOFileSystem.FilePath(filePath.string)
    }
}

/// Fixture for copy benchmarks - source file created ONCE
final class CopyFixture: @unchecked Sendable {
    let dir: File.Path
    let sourcePath: File.Path
    let nioSourcePath: _NIOFileSystem.FilePath

    static let shared: CopyFixture = {
        let fileSize = 100 * 1024 * 1024
        let dir = try! File.Path("/tmp/nio-benchmark-copy-fixture")

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try! File.System.Create.Directory.create(at: dir)

        let sourcePath = dir.appending("copy-source.bin")
        let data = [UInt8](repeating: 0xAB, count: fileSize)
        try! File.System.Write.Streaming.write([data], to: sourcePath, options: .init(commit: .direct()))

        return CopyFixture(dir: dir, sourcePath: sourcePath)
    }()

    private init(dir: File.Path, sourcePath: File.Path) {
        self.dir = dir
        self.sourcePath = sourcePath
        self.nioSourcePath = _NIOFileSystem.FilePath(sourcePath.string)
    }

    func uniqueDestPath() -> (File.Path, _NIOFileSystem.FilePath) {
        let dest = dir.appending("copy-dest-\(UUID().uuidString).bin")
        return (dest, _NIOFileSystem.FilePath(dest.string))
    }
}

/// Fixture for concurrent read benchmarks
final class ConcurrentReadFixture: @unchecked Sendable {
    let paths: [File.Path]
    let nioPaths: [_NIOFileSystem.FilePath]

    static let shared: ConcurrentReadFixture = {
        let fileCount = 100
        let fileSize = 1 * 1024 * 1024
        let dir = try! File.Path("/tmp/nio-benchmark-concurrent-fixture")

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try! File.System.Create.Directory.create(at: dir)

        var paths: [File.Path] = []
        var nioPaths: [_NIOFileSystem.FilePath] = []
        let data = [UInt8](repeating: 0xAB, count: fileSize)

        for i in 0..<fileCount {
            let filePath = dir.appending("concurrent-\(i).bin")
            try! File.System.Write.Streaming.write([data], to: filePath, options: .init(commit: .direct()))
            paths.append(filePath)
            nioPaths.append(_NIOFileSystem.FilePath(filePath.string))
        }

        return ConcurrentReadFixture(paths: paths, nioPaths: nioPaths)
    }()

    private init(paths: [File.Path], nioPaths: [_NIOFileSystem.FilePath]) {
        self.paths = paths
        self.nioPaths = nioPaths
    }
}

/// Fixture for write benchmarks - directory created ONCE
final class WriteFixture: @unchecked Sendable {
    let dir: File.Path
    let nioDir: _NIOFileSystem.FilePath

    static let shared: WriteFixture = {
        let dir = try! File.Path("/tmp/nio-benchmark-write-fixture")

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try! File.System.Create.Directory.create(at: dir)

        return WriteFixture(dir: dir)
    }()

    private init(dir: File.Path) {
        self.dir = dir
        self.nioDir = _NIOFileSystem.FilePath(dir.string)
    }

    func uniquePath() -> (File.Path, _NIOFileSystem.FilePath) {
        let name = UUID().uuidString + ".bin"
        let path = dir.appending(name)
        return (path, _NIOFileSystem.FilePath(path.string))
    }
}

// MARK: - Test Helpers

extension NIOComparison.Test {

    static func uniqueId() -> String {
        UUID().uuidString
    }

    static func createTempDir() throws -> File.Path {
        let path = try File.Path("/tmp/nio-benchmark-\(uniqueId())")
        try File.System.Create.Directory.create(at: path)
        return path
    }

    static func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }
}

// MARK: - Read Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Read {

        static let fileSize = 100 * 1024 * 1024 // 100 MB

        // Fixture is created ONCE, outside timed region
        static let fixture = ReadFixture.shared

        @Test("swift-file-system: read 100MB file", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystem() async throws {
            // ONLY the read is timed - file already exists
            let _ = try await File.System.Read.Full.read(from: Self.fixture.filePath)
        }

        @Test("NIOFileSystem: read 100MB file", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func nioFileSystem() async throws {
            // ONLY the read is timed - file already exists
            let handle = try await FileSystem.shared.openFile(forReadingAt: Self.fixture.nioPath, options: .init())
            var buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(Int64(Self.fileSize)))
            let _ = buffer.readBytes(length: buffer.readableBytes)
            try await handle.close()
        }
    }
}

// MARK: - Write Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Write {

        static let fileSize = 100 * 1024 * 1024 // 100 MB

        // Fixture: directory created ONCE, outside timed region
        static let fixture = WriteFixture.shared

        // Pre-allocate data with FULL page touching (16KB stride on Apple Silicon)
        static let data: [UInt8] = {
            var d = [UInt8](repeating: 0xCD, count: fileSize)
            // Touch ALL pages to avoid page faults during benchmark
            let pageSize = 16384
            for i in stride(from: 0, to: fileSize, by: pageSize) {
                _ = d[i]
            }
            return d
        }()

        // Pre-create ByteBuffer ONCE - COW will share storage
        static let buffer = ByteBuffer(bytes: data)

        // RAW WRITE: Bypass Write.Streaming, use File.Handle directly
        @Test("swift-file-system: write 100MB raw", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystemRaw() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            // Direct File.Handle write - no streaming abstraction
            try Self.data.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .truncate])
                try handle.write(span)
                try handle.close()
            }
        }

        // STREAMING API (sync): Uses Write.Streaming sync path - no io.run overhead
        @Test("swift-file-system: write 100MB streaming-sync", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystemStreamingSync() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            // AnySequence is not Sendable, forces sync overload
            // durability: .none for fair comparison with raw (no fsync)
            let chunks: AnySequence<[UInt8]> = AnySequence([Self.data])
            try File.System.Write.Streaming.write(
                chunks,
                to: filePath,
                options: .init(commit: .direct(.init(durability: .none)))
            )
        }

        // STREAMING API (async): Uses Write.Streaming async path - includes io.run overhead
        @Test("swift-file-system: write 100MB streaming-async", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystemStreamingAsync() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            // Uses async streaming API - includes executor overhead
            // durability: .none for fair comparison with raw (no fsync)
            try await File.System.Write.Streaming.write(
                [Self.data],
                to: filePath,
                options: .init(commit: .direct(.init(durability: .none)))
            )
        }

        // STREAMING API with preallocation: Tests fcntl(F_PREALLOCATE) impact
        @Test("swift-file-system: write 100MB preallocated", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystemPreallocated() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            // AnySequence forces sync overload, with preallocation
            // durability: .none for fair comparison with raw (no fsync)
            let chunks: AnySequence<[UInt8]> = AnySequence([Self.data])
            try File.System.Write.Streaming.write(
                chunks,
                to: filePath,
                options: .init(commit: .direct(.init(durability: .none, expectedSize: Int64(Self.fileSize))))
            )
        }

        @Test("NIOFileSystem: write 100MB", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func nioFileSystem() async throws {
            let (_, nioPath) = Self.fixture.uniquePath()
            let filePath = Self.fixture.dir.appending(nioPath.lastComponent!.string)
            defer { try? File.System.Delete.delete(at: filePath) }

            try await FileSystem.shared.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                // COW copy - does NOT copy 100MB, shares storage with Self.buffer
                var buf = Self.buffer
                try await handle.write(contentsOf: buf.readableBytesView, toAbsoluteOffset: 0)
            }
        }

        // Streaming benchmarks - lazy generation
        @Test("swift-file-system: write 100MB streaming-lazy", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystemStreaming() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            // Generate 1MB chunks lazily
            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize
            let lazyChunks = (0..<chunkCount).lazy.map { _ in
                [UInt8](repeating: 0xCD, count: chunkSize)
            }

            // durability: .none for fair comparison (no fsync)
            try await File.System.Write.Streaming.write(
                lazyChunks,
                to: filePath,
                options: .init(commit: .direct(.init(durability: .none)))
            )
        }

        @Test("NIOFileSystem: write 100MB streaming", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func nioFileSystemStreaming() async throws {
            let (_, nioPath) = Self.fixture.uniquePath()
            let filePath = Self.fixture.dir.appending(nioPath.lastComponent!.string)
            defer { try? File.System.Delete.delete(at: filePath) }

            // Generate 1MB chunks lazily - same as swift-file-system
            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize

            try await FileSystem.shared.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                var offset: Int64 = 0
                for _ in 0..<chunkCount {
                    let chunk = [UInt8](repeating: 0xCD, count: chunkSize)
                    let buffer = ByteBuffer(bytes: chunk)
                    try await handle.write(contentsOf: buffer.readableBytesView, toAbsoluteOffset: offset)
                    offset += Int64(chunkSize)
                }
            }
        }
    }
}

// MARK: - Directory Iteration Benchmarks

extension NIOComparison.Test.Performance {

    @Suite(.serialized)
    struct DirectoryIteration {

        // Reduced scale: 100 and 1000 files (removed 10000)
        static let dir100 = DirectoryIterationFixture(name: "iter-100", fileCount: 100)
        static let dir1000 = DirectoryIterationFixture(name: "iter-1000", fileCount: 1000)

        @Test("swift-file-system: iterate 100 files", .timed(iterations: 5, warmup: 1, trackAllocations: false))
        func swiftFileSystem100() async throws {
            let dir = try Self.dir100.path()

            var count = 0
            for try await _ in File.Directory.Async().entries(at: dir) {
                count += 1
            }
            #expect(count == 100)
        }

        @Test("NIOFileSystem: iterate 100 files", .timed(iterations: 5, warmup: 1, trackAllocations: false))
        func nioFileSystem100() async throws {
            let dir = try Self.dir100.path()

            let nioPath = _NIOFileSystem.FilePath(dir.string)

            var count = 0
            let handle = try await FileSystem.shared.openDirectory(atPath: nioPath)
            for try await _ in handle.listContents() {
                count += 1
            }
            try await handle.close()
            #expect(count == 100)
        }

        @Test("swift-file-system: iterate 1000 files", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystem1000() async throws {
            let dir = try Self.dir1000.path()

            var count = 0
            for try await _ in File.Directory.Async().entries(at: dir) {
                count += 1
            }
            #expect(count == 1000)
        }

        @Test("NIOFileSystem: iterate 1000 files", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func nioFileSystem1000() async throws {
            let dir = try Self.dir1000.path()

            let nioPath = _NIOFileSystem.FilePath(dir.string)

            var count = 0
            let handle = try await FileSystem.shared.openDirectory(atPath: nioPath)
            for try await _ in handle.listContents() {
                count += 1
            }
            try await handle.close()
            #expect(count == 1000)
        }
    }
}

// MARK: - Directory Iteration Fixture

/// Lazily creates a directory with files once, reuses across benchmark iterations.
/// Uses DIRECT write (no fsync) for fast fixture creation.
final class DirectoryIterationFixture: @unchecked Sendable {
    private let name: String
    private let fileCount: Int
    private var cachedPath: File.Path?
    private let lock = NSLock()

    init(name: String, fileCount: Int) {
        self.name = name
        self.fileCount = fileCount
    }

    func path() throws -> File.Path {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedPath {
            return cached
        }

        let dir = try File.Path("/tmp/nio-benchmark-\(name)")

        // Clean up any previous run
        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        // Create directory and files
        try File.System.Create.Directory.create(at: dir)

        // Use DIRECT write - no fsync overhead for fixture creation
        let content = [UInt8]("content".utf8)
        for i in 0..<fileCount {
            let filePath = dir.appending("file-\(String(format: "%05d", i)).txt")
            try File.System.Write.Streaming.write([content], to: filePath, options: .init(commit: .direct()))
        }

        cachedPath = dir
        return dir
    }
}

// MARK: - Copy Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Copy {

        // Fixture is created ONCE, outside timed region
        static let fixture = CopyFixture.shared

        @Test("swift-file-system: copy 100MB file", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func swiftFileSystem() async throws {
            let (destPath, _) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            // ONLY the copy is timed - source already exists
            try await File.System.Copy.copy(from: Self.fixture.sourcePath, to: destPath)
        }

        @Test("NIOFileSystem: copy 100MB file", .timed(iterations: 3, warmup: 1, trackAllocations: false))
        func nioFileSystem() async throws {
            let (destPath, nioDestPath) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            // ONLY the copy is timed - source already exists
            try await FileSystem.shared.copyItem(at: Self.fixture.nioSourcePath, to: nioDestPath)
        }
    }
}

// MARK: - Concurrent Operations Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Concurrent {

        static let fileSize = 1 * 1024 * 1024 // 1 MB each

        // Fixture is created ONCE, outside timed region
        static let fixture = ConcurrentReadFixture.shared

        @Test("swift-file-system: 100 concurrent 1MB reads", .timed(iterations: 2, warmup: 1, trackAllocations: false))
        func swiftFileSystemConcurrentReads() async throws {
            // ONLY the concurrent reads are timed - files already exist
            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in Self.fixture.paths {
                    group.addTask {
                        let _ = try await File.System.Read.Full.read(from: path)
                    }
                }
                try await group.waitForAll()
            }
        }

        @Test("NIOFileSystem: 100 concurrent 1MB reads", .timed(iterations: 2, warmup: 1, trackAllocations: false))
        func nioFileSystemConcurrentReads() async throws {
            let maxSize = Int64(Self.fileSize)

            // ONLY the concurrent reads are timed - files already exist
            try await withThrowingTaskGroup(of: Void.self) { group in
                for nioPath in Self.fixture.nioPaths {
                    group.addTask {
                        let handle = try await FileSystem.shared.openFile(forReadingAt: nioPath, options: .init())
                        var buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(maxSize))
                        let _ = buffer.readBytes(length: buffer.readableBytes)
                        try await handle.close()
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
