//
//  File.System.Write.Streaming Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming {
    #TestSuites
}

extension File.System.Write.Streaming.Test.Unit {

    // MARK: - Test Fixtures

    private func uniquePath(extension ext: String = "txt") -> String {
        "/tmp/streaming-test-\(Int.random(in: 0..<Int.max)).\(ext)"
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath)
        }
    }

    // MARK: - Basic Streaming Write

    @Test("Write multiple chunks and read back")
    func writeMultipleChunks() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [
            [72, 101, 108, 108, 111],  // "Hello"
            [32],  // " "
            [87, 111, 114, 108, 100],  // "World"
        ]

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100])
    }

    @Test("Write empty chunks array")
    func writeEmptyChunks() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = []

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData.isEmpty)
    }

    @Test("Write single chunk")
    func writeSingleChunk() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [[1, 2, 3, 4, 5]]

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [1, 2, 3, 4, 5])
    }

    @Test("Write chunks with empty chunk in middle")
    func writeChunksWithEmptyMiddle() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [
            [1, 2, 3],
            [],  // Empty chunk
            [4, 5, 6],
        ]

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [1, 2, 3, 4, 5, 6])
    }

    @Test("Write large file in chunks")
    func writeLargeFileInChunks() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        // 256KB total in 64KB chunks
        let chunkSize = 64 * 1024
        let chunks: [[UInt8]] = (0..<4).map { i in
            [UInt8](repeating: UInt8(truncatingIfNeeded: i), count: chunkSize)
        }

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData.count == 4 * chunkSize)
    }

    // MARK: - Lazy Sequence Support

    @Test("Write from lazy sequence")
    func writeLazySequence() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        // Lazy sequence that generates chunks on demand
        let lazyChunks = (0..<3).lazy.map { i -> [UInt8] in
            [UInt8](repeating: UInt8(i), count: 10)
        }

        let filePath = try File.Path(path)
        try File.System.Write.Streaming.write(lazyChunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData.count == 30)
        #expect(readData[0..<10] == ArraySlice([UInt8](repeating: 0, count: 10)))
        #expect(readData[10..<20] == ArraySlice([UInt8](repeating: 1, count: 10)))
        #expect(readData[20..<30] == ArraySlice([UInt8](repeating: 2, count: 10)))
    }

    // MARK: - CommitPolicy Tests

    @Test("Atomic write (default) creates file")
    func atomicWriteDefault() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [[1, 2, 3]]
        let filePath = try File.Path(path)

        // Default is atomic
        try File.System.Write.Streaming.write(chunks, to: filePath)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [1, 2, 3])
    }

    @Test("Atomic write with explicit options")
    func atomicWriteExplicit() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [[4, 5, 6]]
        let filePath = try File.Path(path)

        let options = File.System.Write.Streaming.Options(
            commit: .atomic(.init(durability: .full))
        )
        try File.System.Write.Streaming.write(chunks, to: filePath, options: options)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [4, 5, 6])
    }

    @Test("Direct write creates file")
    func directWrite() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let chunks: [[UInt8]] = [[7, 8, 9]]
        let filePath = try File.Path(path)

        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .truncate))
        )
        try File.System.Write.Streaming.write(chunks, to: filePath, options: options)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [7, 8, 9])
    }

    // MARK: - Strategy Tests

    @Test("Atomic noClobber prevents overwrite")
    func atomicNoClobberPreventsOverwrite() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)

        // First write
        try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath)

        // Second write with noClobber should fail
        let options = File.System.Write.Streaming.Options(
            commit: .atomic(.init(strategy: .noClobber))
        )
        #expect(throws: File.System.Write.Streaming.Error.self) {
            try File.System.Write.Streaming.write([[4, 5, 6]], to: filePath, options: options)
        }

        // Original content preserved
        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [1, 2, 3])
    }

    @Test("Direct create strategy prevents overwrite")
    func directCreatePreventsOverwrite() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)

        // First write
        let createOptions = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .truncate))
        )
        try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath, options: createOptions)

        // Second write with create strategy should fail
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .create))
        )
        #expect(throws: File.System.Write.Streaming.Error.self) {
            try File.System.Write.Streaming.write([[4, 5, 6]], to: filePath, options: options)
        }
    }

    @Test("Direct truncate replaces existing")
    func directTruncateReplacesExisting() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)

        // First write
        try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath)

        // Second write with truncate should succeed
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .truncate))
        )
        try File.System.Write.Streaming.write([[4, 5, 6, 7]], to: filePath, options: options)

        let readData = try File.System.Read.Full.read(from: filePath)
        #expect(readData == [4, 5, 6, 7])
    }

    // MARK: - Error Tests

    @Test("parentNotFound error for invalid path")
    func parentNotFoundError() {
        #expect(throws: File.System.Write.Streaming.Error.self) {
            let chunks: [[UInt8]] = [[1, 2, 3]]
            let filePath = File.Path("/nonexistent/directory/file.txt")
            try File.System.Write.Streaming.write(chunks, to: filePath)
        }
    }

    // MARK: - Error Descriptions

    @Test("parent error description")
    func parentErrorDescription() {
        let parentError = File.System.Parent.Check.Error.missing(
            path: "/nonexistent/parent"
        )
        let error = File.System.Write.Streaming.Error.parent(parentError)
        #expect(error.description.contains("Parent directory"))
    }

    @Test("destinationExists error description")
    func destinationExistsErrorDescription() {
        let error = File.System.Write.Streaming.Error.destinationExists(
            path: "/tmp/existing.txt"
        )
        #expect(error.description.contains("already exists"))
    }

    @Test("writeFailed error description")
    func writeFailedErrorDescription() {
        let error = File.System.Write.Streaming.Error.writeFailed(
            path: "/tmp/test.txt",
            bytesWritten: 100,
            errno: 28,
            message: "No space left on device"
        )
        #expect(error.description.contains("Write failed"))
        #expect(error.description.contains("100"))
    }

    // MARK: - Options Tests

    @Test("Default options use atomic commit")
    func defaultOptionsAtomic() {
        let options = File.System.Write.Streaming.Options()
        if case .atomic = options.commit {
            // Expected
        } else {
            Issue.record("Default commit should be atomic")
        }
    }

    @Test("Direct.Options default values")
    func directOptionsDefaults() {
        let options = File.System.Write.Streaming.Direct.Options()
        #expect(options.strategy == .truncate)
        #expect(options.durability == .full)
    }

    @Test("Direct.Options custom values")
    func directOptionsCustom() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .dataOnly
        )
        #expect(options.strategy == .create)
        #expect(options.durability == .dataOnly)
    }

    @Test("Atomic.Options default values")
    func atomicOptionsDefaults() {
        let options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
    }

    @Test("Atomic.Options custom values")
    func atomicOptionsCustom() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly
        )
        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
    }

    @Test("durabilityNotGuaranteed error description")
    func durabilityNotGuaranteedErrorDescription() {
        let error = File.System.Write.Streaming.Error.durabilityNotGuaranteed(
            path: "/tmp/test.txt",
            reason: "Task was cancelled"
        )
        #expect(error.description.contains("durability not guaranteed"))
        #expect(error.description.contains("cancelled"))
    }

    @Test("directorySyncFailedAfterCommit error description")
    func directorySyncFailedAfterCommitErrorDescription() {
        let error = File.System.Write.Streaming.Error.directorySyncFailedAfterCommit(
            path: "/tmp/test.txt",
            errno: 5,
            message: "I/O error"
        )
        #expect(error.description.contains("Directory sync failed after commit"))
        #expect(error.description.contains("I/O error"))
    }
}

// MARK: - Performance Tests

extension File.System.Write.Streaming.Test.Performance {

    @Test("Streaming write 1MB in 64KB chunks", .timed(iterations: 10, warmup: 2))
    func streamingWrite1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td,
            appending: "perf_streaming_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        // 1MB in 16 x 64KB chunks
        let chunkSize = 64 * 1024
        let chunks: [[UInt8]] = (0..<16).map { _ in
            [UInt8](repeating: 0xEF, count: chunkSize)
        }

        try File.System.Write.Streaming.write(chunks, to: filePath)
    }

    @Test("Streaming write 1MB with lazy sequence", .timed(iterations: 10, warmup: 2))
    func streamingWriteLazy1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td,
            appending: "perf_lazy_streaming_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        // Lazy generation - memory efficient
        let chunkSize = 64 * 1024
        let lazyChunks = (0..<16).lazy.map { _ in
            [UInt8](repeating: 0xEF, count: chunkSize)
        }

        try File.System.Write.Streaming.write(lazyChunks, to: filePath)
    }

    @Test("Direct streaming write 1MB (no atomicity)", .timed(iterations: 10, warmup: 2))
    func directStreamingWrite1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td,
            appending: "perf_direct_streaming_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        let chunkSize = 64 * 1024
        let chunks: [[UInt8]] = (0..<16).map { _ in
            [UInt8](repeating: 0xEF, count: chunkSize)
        }

        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(durability: .none))
        )
        try File.System.Write.Streaming.write(chunks, to: filePath, options: options)
    }
}
