//
//  NIOComparisonBenchmarks.swift
//  swift-file-system
//
//  Benchmarks comparing swift-file-system vs NIOFileSystem performance.
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

// MARK: - Test Fixtures

extension NIOComparison.Test {

    static func uniqueId() -> String {
        String(Int.random(in: 0..<Int.max))
    }

    static func createTempDir() throws -> File.Path {
        let path = try File.Path("/tmp/nio-benchmark-\(uniqueId())")
        try File.System.Create.Directory.create(at: path)
        return path
    }

    static func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }

    static func createTestFile(at path: File.Path, size: Int) throws {
        let data = [UInt8](repeating: 0xAB, count: size)
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
    }

    static func createFiles(in dir: File.Path, count: Int) throws {
        for i in 0..<count {
            let filePath = dir.appending("file-\(String(format: "%05d", i)).txt")
            try "content".utf8.withContiguousStorageIfAvailable { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: filePath)
            }
        }
    }
}

// MARK: - Read Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Read {

        static let fileSize = 100 * 1024 * 1024 // 100 MB

        @Test("swift-file-system: read 100MB file", .timed(iterations: 5, warmup: 1))
        func swiftFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let filePath = dir.appending("large-read.bin")
            try NIOComparison.Test.createTestFile(at: filePath, size: Self.fileSize)

            let _ = try await File.System.Read.Full.read(from: filePath)
        }

        @Test("NIOFileSystem: read 100MB file", .timed(iterations: 5, warmup: 1))
        func nioFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let filePath = dir.appending("large-read-nio.bin")
            try NIOComparison.Test.createTestFile(at: filePath, size: Self.fileSize)

            let nioPath = _NIOFileSystem.FilePath(filePath.string)
            let fs = FileSystem.shared

            let handle = try await fs.openFile(forReadingAt: nioPath, options: .init())
            let info = try await handle.info()
            var buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(info.size))
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
        static let data = [UInt8](repeating: 0xCD, count: fileSize)

        @Test("swift-file-system: write 100MB file", .timed(iterations: 5, warmup: 1))
        func swiftFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let filePath = dir.appending("write-test-\(NIOComparison.Test.uniqueId()).bin")
            try await File.System.Write.Atomic.write(Self.data, to: filePath)
        }

        @Test("NIOFileSystem: write 100MB file", .timed(iterations: 5, warmup: 1))
        func nioFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let filePath = dir.appending("write-test-nio-\(NIOComparison.Test.uniqueId()).bin")
            let nioPath = _NIOFileSystem.FilePath(filePath.string)
            let fs = FileSystem.shared

            try await fs.withFileHandle(
                forWritingAt: nioPath,
                options: .newFile(replaceExisting: true)
            ) { handle in
                let buffer = ByteBuffer(bytes: Self.data)
                try await handle.write(contentsOf: buffer.readableBytesView, toAbsoluteOffset: 0)
            }
        }
    }
}

// MARK: - Directory Iteration Benchmarks

extension NIOComparison.Test.Performance {

    @Suite(.serialized)
    struct DirectoryIteration {

        // Shared test directories - created once, reused across iterations
        static let dir1000 = DirectoryIterationFixture(name: "iter-1000", fileCount: 1000)
        static let dir10000 = DirectoryIterationFixture(name: "iter-10000", fileCount: 10_000)

        @Test("swift-file-system: iterate 1000 files", .timed(iterations: 50, warmup: 5))
        func swiftFileSystem1000() async throws {
            let dir = try Self.dir1000.path()

            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            var count = 0
            for try await _ in File.Directory.Async(io: io).entries(at: dir) {
                count += 1
            }
            #expect(count == 1000)
        }

        @Test("NIOFileSystem: iterate 1000 files", .timed(iterations: 50, warmup: 5))
        func nioFileSystem1000() async throws {
            let dir = try Self.dir1000.path()

            let nioPath = _NIOFileSystem.FilePath(dir.string)
            let fs = FileSystem.shared

            var count = 0
            let handle = try await fs.openDirectory(atPath: nioPath)
            for try await _ in handle.listContents() {
                count += 1
            }
            try await handle.close()
            #expect(count == 1000)
        }

        @Test("swift-file-system: iterate 10000 files", .timed(iterations: 20, warmup: 2))
        func swiftFileSystem10000() async throws {
            let dir = try Self.dir10000.path()

            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            var count = 0
            for try await _ in File.Directory.Async(io: io).entries(at: dir) {
                count += 1
            }
            #expect(count == 10_000)
        }

        @Test("NIOFileSystem: iterate 10000 files", .timed(iterations: 20, warmup: 2))
        func nioFileSystem10000() async throws {
            let dir = try Self.dir10000.path()

            let nioPath = _NIOFileSystem.FilePath(dir.string)
            let fs = FileSystem.shared

            var count = 0
            let handle = try await fs.openDirectory(atPath: nioPath)
            for try await _ in handle.listContents() {
                count += 1
            }
            try await handle.close()
            #expect(count == 10_000)
        }
    }
}

// MARK: - Directory Iteration Fixture

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

        // Clean up any previous run
        try? File.System.Delete.delete(at: dir, options: .init(recursive: true))

        // Create directory and files
        try File.System.Create.Directory.create(at: dir)

        for i in 0..<fileCount {
            let filePath = dir.appending("file-\(String(format: "%05d", i)).txt")
            try "content".utf8.withContiguousStorageIfAvailable { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: filePath)
            }
        }

        cachedPath = dir
        return dir
    }
}

// MARK: - Copy Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Copy {

        static let fileSize = 100 * 1024 * 1024 // 100 MB

        @Test("swift-file-system: copy 100MB file", .timed(iterations: 5, warmup: 1))
        func swiftFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let sourcePath = dir.appending("copy-source.bin")
            try NIOComparison.Test.createTestFile(at: sourcePath, size: Self.fileSize)

            let destPath = dir.appending("copy-dest-\(NIOComparison.Test.uniqueId()).bin")
            try await File.System.Copy.copy(from: sourcePath, to: destPath)
        }

        @Test("NIOFileSystem: copy 100MB file", .timed(iterations: 5, warmup: 1))
        func nioFileSystem() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            let sourcePath = dir.appending("copy-source-nio.bin")
            try NIOComparison.Test.createTestFile(at: sourcePath, size: Self.fileSize)

            let nioSourcePath = _NIOFileSystem.FilePath(sourcePath.string)
            let destPath = dir.appending("copy-dest-nio-\(NIOComparison.Test.uniqueId()).bin")
            let nioDestPath = _NIOFileSystem.FilePath(destPath.string)

            let fs = FileSystem.shared
            try await fs.copyItem(at: nioSourcePath, to: nioDestPath)
        }
    }
}

// MARK: - Concurrent Operations Benchmarks

extension NIOComparison.Test.Performance {

    @Suite
    struct Concurrent {

        static let fileCount = 100
        static let fileSize = 1 * 1024 * 1024 // 1 MB each

        @Test("swift-file-system: 100 concurrent 1MB reads", .timed(iterations: 3, warmup: 1))
        func swiftFileSystemConcurrentReads() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            // Create test files
            var paths: [File.Path] = []
            for i in 0..<Self.fileCount {
                let filePath = dir.appending("concurrent-\(i).bin")
                try NIOComparison.Test.createTestFile(at: filePath, size: Self.fileSize)
                paths.append(filePath)
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in paths {
                    group.addTask {
                        let _ = try await File.System.Read.Full.read(from: path)
                    }
                }
                try await group.waitForAll()
            }
        }

        @Test("NIOFileSystem: 100 concurrent 1MB reads", .timed(iterations: 3, warmup: 1))
        func nioFileSystemConcurrentReads() async throws {
            let dir = try NIOComparison.Test.createTempDir()
            defer { NIOComparison.Test.cleanup(dir) }

            // Create test files
            var nioPaths: [_NIOFileSystem.FilePath] = []
            for i in 0..<Self.fileCount {
                let filePath = dir.appending("concurrent-nio-\(i).bin")
                try NIOComparison.Test.createTestFile(at: filePath, size: Self.fileSize)
                nioPaths.append(_NIOFileSystem.FilePath(filePath.string))
            }

            let fs = FileSystem.shared

            try await withThrowingTaskGroup(of: Void.self) { group in
                for nioPath in nioPaths {
                    group.addTask {
                        let handle = try await fs.openFile(forReadingAt: nioPath, options: .init())
                        let info = try await handle.info()
                        var buffer = try await handle.readToEnd(maximumSizeAllowed: .bytes(info.size))
                        let _ = buffer.readBytes(length: buffer.readableBytes)
                        try await handle.close()
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
