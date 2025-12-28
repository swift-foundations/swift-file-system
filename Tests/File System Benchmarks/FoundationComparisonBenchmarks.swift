//
//  FoundationComparisonBenchmarks.swift
//  swift-file-system
//
//  Benchmarks comparing swift-file-system vs Foundation (sync-to-sync).
//
//  ## Purpose
//
//  These benchmarks compare synchronous APIs to isolate syscall performance
//  from async scheduling overhead. Both libraries use blocking calls.
//
//  ## Running
//
//  swift test -c release --filter FoundationComparisonBenchmarks
//

import File_System
import Foundation
import StandardsTestSupport
import Testing

// MARK: - Benchmark Type

enum FoundationComparison {
    #TestSuites
}

// MARK: - Shared Fixtures

/// Fixture for benchmarks - files created ONCE, reused across iterations
final class FoundationFixture: @unchecked Sendable {
    let dir: String
    let file1MB: String
    let file10MB: String
    let file100MB: String
    let filePath1MB: File.Path
    let filePath10MB: File.Path
    let filePath100MB: File.Path

    static let shared: FoundationFixture = {
        let dir = "/tmp/foundation-benchmark-fixture"

        try? FileManager.default.removeItem(atPath: dir)

        do {
            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
        } catch {
            fatalError("Benchmark fixture setup failed: \(error)")
        }

        func createFile(name: String, size: Int) -> String {
            let path = "\(dir)/\(name)"
            let data = Data(repeating: 0xAB, count: size)
            FileManager.default.createFile(atPath: path, contents: data)
            return path
        }

        let file1MB = createFile(name: "1mb.bin", size: 1 * 1024 * 1024)
        let file10MB = createFile(name: "10mb.bin", size: 10 * 1024 * 1024)
        let file100MB = createFile(name: "100mb.bin", size: 100 * 1024 * 1024)

        let fixture = FoundationFixture(
            dir: dir,
            file1MB: file1MB,
            file10MB: file10MB,
            file100MB: file100MB
        )

        // Warmup: trigger any lazy initialization in swift-file-system and Foundation
        // This ensures fair comparison by not counting framework init costs
        _ = try? File.System.Read.Full.read(from: fixture.filePath1MB)
        _ = try? Data(contentsOf: URL(fileURLWithPath: file1MB))

        return fixture
    }()

    private init(dir: String, file1MB: String, file10MB: String, file100MB: String) {
        self.dir = dir
        self.file1MB = file1MB
        self.file10MB = file10MB
        self.file100MB = file100MB
        self.filePath1MB = File.Path(stringLiteral: file1MB)
        self.filePath10MB = File.Path(stringLiteral: file10MB)
        self.filePath100MB = File.Path(stringLiteral: file100MB)
    }
}

/// Fixture for directory iteration
final class FoundationDirectoryFixture: @unchecked Sendable {
    private let name: String
    private let fileCount: Int
    private var cachedPath: String?
    private let lock = NSLock()

    init(name: String, fileCount: Int) {
        self.name = name
        self.fileCount = fileCount
    }

    func path() throws -> (String, File.Path) {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedPath {
            return (cached, File.Path(stringLiteral: cached))
        }

        let dir = "/tmp/foundation-benchmark-\(name)"

        try? FileManager.default.removeItem(atPath: dir)
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )

        let content = Data("content".utf8)
        for i in 0..<fileCount {
            let filePath = "\(dir)/file-\(String(format: "%05d", i)).txt"
            FileManager.default.createFile(atPath: filePath, contents: content)
        }

        cachedPath = dir
        return (dir, File.Path(stringLiteral: dir))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Read Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension FoundationComparison.Test.Performance {

    @Suite
    struct Read {

        static let fixture = FoundationFixture.shared

        @Test(
            "swift-file-system: read 1MB",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem1MB() throws {
            let bytes = try File.System.Read.Full.read(from: Self.fixture.filePath1MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "Foundation: read 1MB",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func foundation1MB() throws {
            let data = try Data(contentsOf: URL(fileURLWithPath: Self.fixture.file1MB))
            withExtendedLifetime(data.count) {}
        }

        @Test(
            "swift-file-system: read 10MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem10MB() throws {
            let bytes = try File.System.Read.Full.read(from: Self.fixture.filePath10MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "Foundation: read 10MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func foundation10MB() throws {
            let data = try Data(contentsOf: URL(fileURLWithPath: Self.fixture.file10MB))
            withExtendedLifetime(data.count) {}
        }

        @Test(
            "swift-file-system: read 100MB",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func swiftFileSystem100MB() throws {
            let bytes = try File.System.Read.Full.read(from: Self.fixture.filePath100MB)
            withExtendedLifetime(bytes.count) {}
        }

        @Test(
            "Foundation: read 100MB",
            .timed(iterations: 3, warmup: 1, trackAllocations: false)
        )
        func foundation100MB() throws {
            let data = try Data(contentsOf: URL(fileURLWithPath: Self.fixture.file100MB))
            withExtendedLifetime(data.count) {}
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Write Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension FoundationComparison.Test.Performance {

    @Suite
    struct Write {

        static let fileSize = 100 * 1024 * 1024
        static let dir = "/tmp/foundation-benchmark-write"

        static let data: [UInt8] = {
            var d = [UInt8](repeating: 0xCD, count: fileSize)
            let pageSize = 16384
            for i in stride(from: 0, to: fileSize, by: pageSize) {
                _ = d[i]
            }
            return d
        }()

        static let foundationData = Data(data)

        init() {
            try? FileManager.default.removeItem(atPath: Self.dir)
            try? FileManager.default.createDirectory(
                atPath: Self.dir,
                withIntermediateDirectories: true
            )
        }

        func uniquePath() -> (File.Path, String) {
            let name = UUID().uuidString + ".bin"
            let path = "\(Self.dir)/\(name)"
            return (File.Path(stringLiteral: path), path)
        }

        @Test(
            "swift-file-system: write 100MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem() throws {
            let (filePath, stringPath) = uniquePath()
            defer { try? FileManager.default.removeItem(atPath: stringPath) }

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
            "Foundation: write 100MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func foundation() throws {
            let (_, stringPath) = uniquePath()
            defer { try? FileManager.default.removeItem(atPath: stringPath) }

            try Self.foundationData.write(to: URL(fileURLWithPath: stringPath))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Directory Iteration Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension FoundationComparison.Test.Performance {

    @Suite(.serialized)
    struct DirectoryIteration {

        static let dir100 = FoundationDirectoryFixture(name: "iter-100", fileCount: 100)
        static let dir1000 = FoundationDirectoryFixture(name: "iter-1000", fileCount: 1000)

        @Test(
            "swift-file-system: iterate 100 files",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem100() throws {
            let (_, filePath) = try Self.dir100.path()

            var count = 0
            for _ in try File.Directory.Contents.list(at: File.Directory(filePath)) {
                count += 1
            }
            #expect(count == 100)
        }

        @Test(
            "Foundation: iterate 100 files",
            .timed(iterations: 10, warmup: 2, trackAllocations: false)
        )
        func foundation100() throws {
            let (dir, _) = try Self.dir100.path()

            let contents = try FileManager.default.contentsOfDirectory(atPath: dir)
            #expect(contents.count == 100)
        }

        @Test(
            "swift-file-system: iterate 1000 files",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem1000() throws {
            let (_, filePath) = try Self.dir1000.path()

            var count = 0
            for _ in try File.Directory.Contents.list(at: File.Directory(filePath)) {
                count += 1
            }
            #expect(count == 1000)
        }

        @Test(
            "Foundation: iterate 1000 files",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func foundation1000() throws {
            let (dir, _) = try Self.dir1000.path()

            let contents = try FileManager.default.contentsOfDirectory(atPath: dir)
            #expect(contents.count == 1000)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Metadata Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension FoundationComparison.Test.Performance {

    @Suite
    struct Metadata {

        static let fixture = FoundationFixture.shared

        @Test(
            "swift-file-system: stat file",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func swiftFileSystemStat() throws {
            let info = try File.System.Stat.info(at: Self.fixture.filePath1MB)
            withExtendedLifetime(info.size) {}
        }

        @Test(
            "Foundation: stat file",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func foundationStat() throws {
            let attrs = try FileManager.default.attributesOfItem(atPath: Self.fixture.file1MB)
            withExtendedLifetime(attrs[.size]) {}
        }

        @Test(
            "swift-file-system: file exists",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func swiftFileSystemExists() throws {
            let exists = File.System.Stat.exists(at: Self.fixture.filePath1MB)
            #expect(exists)
        }

        @Test(
            "Foundation: file exists",
            .timed(iterations: 20, warmup: 5, trackAllocations: false)
        )
        func foundationExists() throws {
            let exists = FileManager.default.fileExists(atPath: Self.fixture.file1MB)
            #expect(exists)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Copy Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

extension FoundationComparison.Test.Performance {

    @Suite
    struct Copy {

        static let fixture = FoundationFixture.shared

        @Test(
            "swift-file-system: copy 100MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func swiftFileSystem() throws {
            let dest = File.Path(stringLiteral: "/tmp/foundation-benchmark-copy-\(UUID().uuidString).bin")
            defer { try? File.System.Delete.delete(at: dest) }

            try File.System.Copy.copy(from: Self.fixture.filePath100MB, to: dest)
        }

        @Test(
            "Foundation: copy 100MB",
            .timed(iterations: 5, warmup: 2, trackAllocations: false)
        )
        func foundation() throws {
            let dest = "/tmp/foundation-benchmark-copy-\(UUID().uuidString).bin"
            defer { try? FileManager.default.removeItem(atPath: dest) }

            try FileManager.default.copyItem(atPath: Self.fixture.file100MB, toPath: dest)
        }
    }
}
