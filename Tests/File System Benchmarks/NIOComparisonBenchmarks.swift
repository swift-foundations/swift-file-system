//
//  NIOComparisonBenchmarks.swift
//  swift-file-system
//
//  Benchmarks comparing swift-file-system vs NIOFileSystem performance.
//
//  ## What These Benchmarks Measure
//
//  These are HOT-CACHE benchmarks measuring:
//  - Memory bandwidth (kernel → user copy from page cache)
//  - API overhead and buffer plumbing
//  - Syscall strategy differences
//
//  These benchmarks do NOT measure:
//  - Cold-storage throughput (macOS lacks reliable cache control without root)
//  - Disk I/O latency under load
//
//  ## Fairness Rules
//
//  - Setup (file creation) is outside timed regions
//  - Both use same allocation patterns (pre-allocated OR both allocate per-chunk)
//  - Both use direct/no-fsync mode (matched durability)
//  - All pages pre-touched to avoid page fault overhead
//  - API shape differences are named explicitly
//
//  ## Running
//
//  swift test -c release --filter NIOComparisonBenchmarks
//

import File_System
import File_System_Async
import Foundation
import NIOCore
import StandardsTestSupport
import Testing
import _NIOFileSystem

// MARK: - Benchmark Type

enum NIOComparison {
    #TestSuites
}

// MARK: - Shared Fixtures

/// Fixture for read benchmarks - files created ONCE, reused across iterations
final class ReadFixture: @unchecked Sendable {
    let dir: File.Path

    // Multiple sizes for scaling analysis
    let file1MB: File.Path
    let file10MB: File.Path
    let file100MB: File.Path

    let nioFile1MB: _NIOFileSystem.FilePath
    let nioFile10MB: _NIOFileSystem.FilePath
    let nioFile100MB: _NIOFileSystem.FilePath

    static let shared: ReadFixture = {
        let dir: File.Path = "/tmp/nio-benchmark-read-fixture"

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        do {
            try File.System.Create.Directory.create(at: dir)
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

        func createFile(name: String, size: Int) -> File.Path {
            let path = dir.appending(name)
            let data = [UInt8](repeating: 0xAB, count: size)
            do {
                try File.System.Write.Streaming.write(
                    [data],
                    to: path,
                    options: .init(commit: .direct())
                )
            } catch {
                fatalError("Benchmark fixture setup failed: \(error)")
            }
            return path
        }

        let file1MB = createFile(name: "1mb.bin", size: 1 * 1024 * 1024)
        let file10MB = createFile(name: "10mb.bin", size: 10 * 1024 * 1024)
        let file100MB = createFile(name: "100mb.bin", size: 100 * 1024 * 1024)

        return ReadFixture(
            dir: dir,
            file1MB: file1MB,
            file10MB: file10MB,
            file100MB: file100MB
        )
    }()

    private init(dir: File.Path, file1MB: File.Path, file10MB: File.Path, file100MB: File.Path) {
        self.dir = dir
        self.file1MB = file1MB
        self.file10MB = file10MB
        self.file100MB = file100MB
        self.nioFile1MB = _NIOFileSystem.FilePath(file1MB.string)
        self.nioFile10MB = _NIOFileSystem.FilePath(file10MB.string)
        self.nioFile100MB = _NIOFileSystem.FilePath(file100MB.string)
    }
}

/// Fixture for copy benchmarks - source file created ONCE
final class CopyFixture: @unchecked Sendable {
    let dir: File.Path
    let sourcePath: File.Path
    let nioSourcePath: _NIOFileSystem.FilePath

    static let shared: CopyFixture = {
        let fileSize = 100 * 1024 * 1024
        let dir: File.Path = "/tmp/nio-benchmark-copy-fixture"

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        do {
            try File.System.Create.Directory.create(at: dir)
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

        let sourcePath = dir.appending("copy-source.bin")
        let data = [UInt8](repeating: 0xAB, count: fileSize)
        do {
            try File.System.Write.Streaming.write(
                [data],
                to: sourcePath,
                options: .init(commit: .direct())
            )
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

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
        let dir: File.Path = "/tmp/nio-benchmark-concurrent-fixture"

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        do {
            try File.System.Create.Directory.create(at: dir)
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

        var paths: [File.Path] = []
        var nioPaths: [_NIOFileSystem.FilePath] = []
        let data = [UInt8](repeating: 0xAB, count: fileSize)

        for i in 0..<fileCount {
            let filePath = dir.appending("concurrent-\(i).bin")
            do {
                try File.System.Write.Streaming.write(
                    [data],
                    to: filePath,
                    options: .init(commit: .direct())
                )
            } catch {
                fatalError("Benchmark fixture setup failed: \(error)")
            }
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
        let dir: File.Path = "/tmp/nio-benchmark-write-fixture"

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        do {
            try File.System.Create.Directory.create(at: dir)
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

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

/// Lazily creates a directory with files once, reuses across benchmark iterations.
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

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try File.System.Create.Directory.create(at: dir)

        let content = [UInt8]("content".utf8)
        for i in 0..<fileCount {
            let filePath = dir.appending("file-\(String(format: "%05d", i)).txt")
            try File.System.Write.Streaming.write(
                [content],
                to: filePath,
                options: .init(commit: .direct())
            )
        }

        cachedPath = dir
        return dir
    }
}

/// Fixture for recursive directory walk - nested structure
final class DirectoryWalkFixture: @unchecked Sendable {
    private var cachedPath: File.Path?
    private let lock = NSLock()

    static let shared = DirectoryWalkFixture()

    /// Creates: 10 dirs × 10 subdirs × 10 files = 1000 files total
    func path() throws -> File.Path {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedPath {
            return cached
        }

        let dir = try File.Path("/tmp/nio-benchmark-walk")

        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))
        try File.System.Create.Directory.create(at: dir)

        let content = [UInt8]("content".utf8)
        for i in 0..<10 {
            let subdir1 = dir.appending("dir-\(i)")
            try File.System.Create.Directory.create(at: subdir1)

            for j in 0..<10 {
                let subdir2 = subdir1.appending("subdir-\(j)")
                try File.System.Create.Directory.create(at: subdir2)

                for k in 0..<10 {
                    let filePath = subdir2.appending("file-\(k).txt")
                    try File.System.Write.Streaming.write(
                        [content],
                        to: filePath,
                        options: .init(commit: .direct())
                    )
                }
            }
        }

        cachedPath = dir
        return dir
    }
}

// MARK: - Test Helpers

extension NIOComparison.Test {
    static func uniqueId() -> String {
        UUID().uuidString
    }

    static func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Read Benchmarks
// ═══════════════════════════════════════════════════════════════════════════
//
// Measures memory bandwidth and API overhead (hot-cache reads).

extension NIOComparison.Test.Performance {

    @Suite
    struct Read {

        static let fixture = ReadFixture.shared

        // MARK: - Full File Reads (Different Sizes)

        @Test(
            "swift-file-system: read 1MB",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem1MB() async throws {
            let bytes = try await File.System.Read.Full.read(from: Self.fixture.file1MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "NIOFileSystem: read 1MB",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func nioFileSystem1MB() async throws {
            let handle = try await FileSystem.shared.openFile(
                forReadingAt: Self.fixture.nioFile1MB,
                options: .init()
            )
            let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(1 * 1024 * 1024))
            withExtendedLifetime(buffer.readableBytes) {}
            try await handle.close()
        }

        @Test(
            "swift-file-system: read 10MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem10MB() async throws {
            let bytes = try await File.System.Read.Full.read(from: Self.fixture.file10MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "NIOFileSystem: read 10MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func nioFileSystem10MB() async throws {
            let handle = try await FileSystem.shared.openFile(
                forReadingAt: Self.fixture.nioFile10MB,
                options: .init()
            )
            let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(10 * 1024 * 1024))
            withExtendedLifetime(buffer.readableBytes) {}
            try await handle.close()
        }

        @Test(
            "swift-file-system: read 100MB",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystem100MB() async throws {
            let bytes = try await File.System.Read.Full.read(from: Self.fixture.file100MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "NIOFileSystem: read 100MB",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func nioFileSystem100MB() async throws {
            let handle = try await FileSystem.shared.openFile(
                forReadingAt: Self.fixture.nioFile100MB,
                options: .init()
            )
            let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(100 * 1024 * 1024))
            withExtendedLifetime(buffer.readableBytes) {}
            try await handle.close()
        }

        // MARK: - Chunked Reads (64KB chunks from 100MB file)

        @Test(
            "swift-file-system: read 100MB chunked (64KB)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystemChunked() async throws {
            let fs = File.System.Async()

            let options = File.System.Read.Async.Options(chunkSize: 64 * 1024)
            let stream = File.System.Read.bytes(from: Self.fixture.file100MB, options: options, fs: fs)

            var totalBytes = 0
            for try await chunk in stream {
                totalBytes += chunk.count
            }
            #expect(totalBytes == 100 * 1024 * 1024)

            await fs.shutdown()
        }

        @Test(
            "NIOFileSystem: read 100MB chunked (64KB)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func nioFileSystemChunked() async throws {
            let handle = try await FileSystem.shared.openFile(
                forReadingAt: Self.fixture.nioFile100MB,
                options: .init()
            )

            var totalBytes = 0
            var offset: Int64 = 0
            let chunkSize: Int64 = 64 * 1024

            while true {
                let buffer = try await handle.readChunk(
                    fromAbsoluteOffset: offset,
                    length: .bytes(chunkSize)
                )
                if buffer.readableBytes == 0 { break }
                totalBytes += buffer.readableBytes
                offset += Int64(buffer.readableBytes)
            }

            try await handle.close()
            #expect(totalBytes == 100 * 1024 * 1024)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Write Benchmarks
// ═══════════════════════════════════════════════════════════════════════════
//
// ## Fairness Notes
//
// - Both use pre-allocated data (no allocation during timed region)
// - Both use no-fsync mode
// - Streaming tests: both allocate fresh chunks in loop (matched pattern)

extension NIOComparison.Test.Performance {

    @Suite
    struct Write {

        static let fileSize = 100 * 1024 * 1024  // 100 MB
        static let fixture = WriteFixture.shared

        // Pre-allocate data with page touching
        static let data: [UInt8] = {
            var d = [UInt8](repeating: 0xCD, count: fileSize)
            let pageSize = 16384
            for i in stride(from: 0, to: fileSize, by: pageSize) {
                _ = d[i]
            }
            return d
        }()

        static let buffer = ByteBuffer(bytes: data)

        // MARK: - Single Buffer Write (100MB at once)

        @Test(
            "swift-file-system: write 100MB (single buffer)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystemSingleBuffer() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            try Self.data.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                var handle = try File.Handle.open(
                    filePath,
                    mode: .write,
                    options: [.create, .truncate]
                )
                try handle.write(span)
                try handle.close()
            }
        }

        @Test(
            "NIOFileSystem: write 100MB (single buffer)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func nioFileSystemSingleBuffer() async throws {
            let (filePath, nioPath) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            try await FileSystem.shared.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                try await handle.write(contentsOf: Self.buffer.readableBytesView, toAbsoluteOffset: 0)
            }
        }

        // MARK: - Streaming Write (1MB chunks, FAIR: both allocate per-chunk)

        @Test(
            "swift-file-system: write 100MB streaming (1MB chunks)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystemStreaming() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize

            // Allocate chunks in loop (matches NIO pattern)
            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .truncate]
            )

            for _ in 0..<chunkCount {
                let chunk = [UInt8](repeating: 0xCD, count: chunkSize)
                try chunk.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try handle.write(span)
                }
            }

            try handle.close()
        }

        @Test(
            "NIOFileSystem: write 100MB streaming (1MB chunks)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func nioFileSystemStreaming() async throws {
            let (filePath, nioPath) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize

            try await FileSystem.shared.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                var offset: Int64 = 0
                for _ in 0..<chunkCount {
                    // Allocate chunk in loop (matches swift pattern)
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

        // MARK: - Pre-allocated Streaming (reuse buffer)

        @Test(
            "swift-file-system: write 100MB streaming (pre-allocated)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystemStreamingPreallocated() async throws {
            let (filePath, _) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize
            let chunk = [UInt8](repeating: 0xCD, count: chunkSize)

            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .truncate]
            )

            for _ in 0..<chunkCount {
                try chunk.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try handle.write(span)
                }
            }

            try handle.close()
        }

        @Test(
            "NIOFileSystem: write 100MB streaming (pre-allocated)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func nioFileSystemStreamingPreallocated() async throws {
            let (filePath, nioPath) = Self.fixture.uniquePath()
            defer { try? File.System.Delete.delete(at: filePath) }

            let chunkSize = 1024 * 1024
            let chunkCount = Self.fileSize / chunkSize
            let chunk = [UInt8](repeating: 0xCD, count: chunkSize)
            let chunkBuffer = ByteBuffer(bytes: chunk)

            try await FileSystem.shared.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                var offset: Int64 = 0
                for _ in 0..<chunkCount {
                    try await handle.write(
                        contentsOf: chunkBuffer.readableBytesView,
                        toAbsoluteOffset: offset
                    )
                    offset += Int64(chunkSize)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Directory Iteration Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension NIOComparison.Test.Performance {

    @Suite(.serialized)
    struct DirectoryIteration {

        static let dir100 = DirectoryIterationFixture(name: "iter-100", fileCount: 100)
        static let dir1000 = DirectoryIterationFixture(name: "iter-1000", fileCount: 1000)

        // MARK: - Flat Directory (100 files)

        @Test(
            "swift-file-system: iterate 100 files",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem100() async throws {
            let dir = try Self.dir100.path()

            var count = 0
            for try await _ in File.Directory.entries(at: File.Directory(dir)) {
                count += 1
            }
            #expect(count == 100)
        }

        @Test(
            "NIOFileSystem: iterate 100 files",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
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

        // MARK: - Flat Directory (1000 files)

        @Test(
            "swift-file-system: iterate 1000 files",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem1000() async throws {
            let dir = try Self.dir1000.path()

            var count = 0
            for try await _ in File.Directory.entries(at: File.Directory(dir)) {
                count += 1
            }
            #expect(count == 1000)
        }

        @Test(
            "NIOFileSystem: iterate 1000 files",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
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

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Recursive Directory Walk Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension NIOComparison.Test.Performance {

    @Suite(.serialized)
    struct DirectoryWalk {

        static let fixture = DirectoryWalkFixture.shared

        // 10 dirs × 10 subdirs × 10 files = 1000 files + 110 directories

        @Test(
            "swift-file-system: walk 1000 files (recursive)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystemWalk() async throws {
            let dir = try Self.fixture.path()

            var count = 0
            for try await _ in File.Directory.walk(at: File.Directory(dir)) {
                count += 1
            }
            // 1000 files + 100 subdirs + 10 dirs = 1110 entries
            #expect(count == 1110)
        }

        // Note: NIO doesn't have a built-in recursive walk API
        // We implement it manually for fair comparison
        @Test(
            "NIOFileSystem: walk 1000 files (recursive)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func nioFileSystemWalk() async throws {
            let dir = try Self.fixture.path()
            let nioPath = _NIOFileSystem.FilePath(dir.string)

            var count = 0
            var stack: [_NIOFileSystem.FilePath] = [nioPath]

            while let current = stack.popLast() {
                let handle = try await FileSystem.shared.openDirectory(atPath: current)
                for try await entry in handle.listContents() {
                    count += 1
                    if entry.type == .directory {
                        stack.append(entry.path)
                    }
                }
                try await handle.close()
            }

            #expect(count == 1110)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Copy Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension NIOComparison.Test.Performance {

    @Suite
    struct Copy {

        static let fileSize = 100 * 1024 * 1024
        static let fixture = CopyFixture.shared

        // MARK: - APFS Clone (metadata-only)

        @Test(
            "swift-file-system: copy 100MB (APFS clone)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystemClone() async throws {
            let (destPath, _) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            try await File.System.Copy.copy(from: Self.fixture.sourcePath, to: destPath)
        }

        @Test(
            "NIOFileSystem: copy 100MB (APFS clone)",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func nioFileSystemClone() async throws {
            let (destPath, nioDestPath) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            try await FileSystem.shared.copyItem(at: Self.fixture.nioSourcePath, to: nioDestPath)
        }

        // MARK: - Byte Copy (64KB chunks)

        @Test(
            "swift-file-system: copy 100MB (byte loop)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystemBytes() async throws {
            let (destPath, _) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            try await File.System.Copy.copy(
                from: Self.fixture.sourcePath,
                to: destPath,
                options: .init(copyAttributes: false)
            )
        }

        @Test(
            "NIOFileSystem: copy 100MB (byte loop)",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func nioFileSystemBytes() async throws {
            let (destPath, nioDestPath) = Self.fixture.uniqueDestPath()
            defer { try? File.System.Delete.delete(at: destPath) }

            let chunkSize = 64 * 1024
            let readHandle = try await FileSystem.shared.openFile(
                forReadingAt: Self.fixture.nioSourcePath,
                options: .init()
            )

            do {
                try await FileSystem.shared.withFileHandle(
                    forWritingAt: nioDestPath,
                    options: .newFile(replaceExisting: true)
                ) { writeHandle in
                    var offset: Int64 = 0
                    while true {
                        let buffer = try await readHandle.readChunk(
                            fromAbsoluteOffset: offset,
                            length: .bytes(Int64(chunkSize))
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
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Concurrent Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension NIOComparison.Test.Performance {

    @Suite
    struct Concurrent {

        static let fileSize = 1 * 1024 * 1024
        static let fixture = ConcurrentReadFixture.shared

        // MARK: - Concurrent Reads

        @Test(
            "swift-file-system: 100 concurrent 1MB reads",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystemConcurrentReads() async throws {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in Self.fixture.paths {
                    group.addTask {
                        let bytes = try await File.System.Read.Full.read(from: path)
                        withExtendedLifetime(bytes.count) {}
                    }
                }
                try await group.waitForAll()
            }
        }

        @Test(
            "NIOFileSystem: 100 concurrent 1MB reads",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func nioFileSystemConcurrentReads() async throws {
            let maxSize = Int64(Self.fileSize)

            try await withThrowingTaskGroup(of: Void.self) { group in
                for nioPath in Self.fixture.nioPaths {
                    group.addTask {
                        let handle = try await FileSystem.shared.openFile(
                            forReadingAt: nioPath,
                            options: .init()
                        )
                        let buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(maxSize))
                        withExtendedLifetime(buffer.readableBytes) {}
                        try await handle.close()
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Metadata Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension NIOComparison.Test.Performance {

    @Suite
    struct Metadata {

        static let fixture = ReadFixture.shared

        @Test(
            "swift-file-system: stat file",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func swiftFileSystemStat() throws {
            let info = try File.System.Stat.info(at: Self.fixture.file1MB)
            withExtendedLifetime(info.size) {}
        }

        @Test(
            "NIOFileSystem: stat file",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func nioFileSystemStat() async throws {
            let info = try await FileSystem.shared.info(forFileAt: Self.fixture.nioFile1MB)
            withExtendedLifetime(info?.size) {}
        }

        @Test(
            "swift-file-system: file exists check",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func swiftFileSystemExists() throws {
            let exists = File.System.Stat.exists(at: Self.fixture.file1MB)
            #expect(exists)
        }

        @Test(
            "NIOFileSystem: file exists check",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func nioFileSystemExists() async throws {
            let info = try await FileSystem.shared.info(forFileAt: Self.fixture.nioFile1MB)
            #expect(info != nil)
        }
    }
}
