//
//  File.Handle Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Handle {
    #TestSuites
}

extension File.Handle.Test.Unit {
    // MARK: - Test Fixtures

    private func writeBytes(_ bytes: [UInt8], to path: File.Path) throws {
        var bytes = bytes
        try bytes.withUnsafeMutableBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
    }

    private func createTempFile(content: [UInt8] = []) throws -> String {
        let path = "/tmp/handle-test-\(Int.random(in: 0..<Int.max)).bin"
        try writeBytes(content, to: try File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - Opening

    @Test("Open file for reading")
    func openForReading() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)
        let isValid = handle.isValid
        let mode = handle.mode
        #expect(isValid)
        #expect(mode == .read)
        try handle.close()
    }

    @Test("Open file for writing")
    func openForWriting() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .write)
        let isValid = handle.isValid
        let mode = handle.mode
        #expect(isValid)
        #expect(mode == .write)
        try handle.close()
    }

    @Test("Open file for read/write")
    func openForReadWrite() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .readWrite)
        let isValid = handle.isValid
        let mode = handle.mode
        #expect(isValid)
        #expect(mode == .readWrite)
        try handle.close()
    }

    @Test("Open file for append")
    func openForAppend() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .append)
        let isValid = handle.isValid
        let mode = handle.mode
        #expect(isValid)
        #expect(mode == .append)
        try handle.close()
    }

    @Test("Open with create option")
    func openWithCreate() throws {
        let path = "/tmp/handle-create-\(Int.random(in: 0..<Int.max)).txt"
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .write, options: [.create])
        let isValid = handle.isValid
        #expect(isValid)
        #expect(File.System.Stat.exists(at: try File.Path(path)))
        try handle.close()
    }

    @Test("Open non-existing file throws pathNotFound")
    func openNonExisting() throws {
        let path = "/tmp/non-existing-\(Int.random(in: 0..<Int.max)).txt"
        let filePath = try File.Path(path)

        #expect(throws: File.Handle.Error.self) {
            _ = try File.Handle.open(filePath, mode: .read)
        }
    }

    // MARK: - Reading

    @Test("Read bytes from file")
    func readBytes() throws {
        let content: [UInt8] = [10, 20, 30, 40, 50]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let readData = try handle.read(count: 5)
        #expect(readData == content)
        try handle.close()
    }

    @Test("Read partial bytes")
    func readPartialBytes() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let firstPart = try handle.read(count: 5)
        #expect(firstPart == [1, 2, 3, 4, 5])

        let secondPart = try handle.read(count: 5)
        #expect(secondPart == [6, 7, 8, 9, 10])
        try handle.close()
    }

    @Test("Read at EOF returns empty")
    func readAtEOF() throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        _ = try handle.read(count: 3)  // Read all
        let atEOF = try handle.read(count: 10)
        #expect(atEOF.isEmpty)
        try handle.close()
    }

    @Test("Read more than available returns available")
    func readMoreThanAvailable() throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let readData = try handle.read(count: 100)
        #expect(readData == content)
        try handle.close()
    }

    // MARK: - Writing

    @Test("Write bytes to file")
    func writeBytes() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

        let data: [UInt8] = [100, 101, 102, 103, 104]
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try handle.write(span)
        }
        try handle.close()

        let readBack = try File.System.Read.Full.read(from: try File.Path(path))
        #expect(readBack == data)
    }

    @Test("Write empty data")
    func writeEmpty() throws {
        let path = try createTempFile(content: [1, 2, 3])
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

        let data: [UInt8] = []
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try handle.write(span)
        }
        try handle.close()

        let readBack = try File.System.Read.Full.read(from: try File.Path(path))
        #expect(readBack.isEmpty)
    }

    // MARK: - Seeking

    @Test("Seek from start")
    func seekFromStart() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let newPos = try handle.seek(to: 5, from: .start)
        #expect(newPos == 5)

        let readData = try handle.read(count: 3)
        #expect(readData == [6, 7, 8])
        try handle.close()
    }

    @Test("Seek from current")
    func seekFromCurrent() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        _ = try handle.read(count: 3)  // Position at 3
        let newPos = try handle.seek(to: 2, from: .current)  // Now at 5
        #expect(newPos == 5)

        let readData = try handle.read(count: 1)
        #expect(readData == [6])
        try handle.close()
    }

    @Test("Seek from end")
    func seekFromEnd() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let newPos = try handle.seek(to: -3, from: .end)
        #expect(newPos == 7)

        let readData = try handle.read(count: 3)
        #expect(readData == [8, 9, 10])
        try handle.close()
    }

    @Test("Get current position")
    func getCurrentPosition() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .read)

        let pos1 = try handle.seek(to: 0, from: .current)
        #expect(pos1 == 0)
        _ = try handle.read(count: 3)
        let pos2 = try handle.seek(to: 0, from: .current)
        #expect(pos2 == 3)
        try handle.close()
    }

    // MARK: - Sync

    @Test("Sync flushes to disk")
    func syncToDisk() throws {
        let path = "/tmp/handle-sync-\(Int.random(in: 0..<Int.max)).txt"
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var handle = try File.Handle.open(filePath, mode: .write, options: [.create])

        let data: [UInt8] = [1, 2, 3]
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try handle.write(span)
        }
        try handle.sync()
        try handle.close()

        // File should exist and have content
        #expect(File.System.Stat.exists(at: try File.Path(path)))
    }

    // MARK: - Error descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.Handle.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root/secret")
        let error = File.Handle.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("invalidHandle error description")
    func invalidHandleErrorDescription() {
        let error = File.Handle.Error.invalidHandle
        #expect(error.description.contains("Invalid"))
    }

    @Test("seekFailed error description")
    func seekFailedErrorDescription() {
        let error = File.Handle.Error.seekFailed(errno: 22, message: "Invalid argument")
        #expect(error.description.contains("Seek failed"))
    }

    @Test("readFailed error description")
    func readFailedErrorDescription() {
        let error = File.Handle.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read failed"))
    }

    @Test("writeFailed error description")
    func writeFailedErrorDescription() {
        let error = File.Handle.Error.writeFailed(errno: 28, message: "No space left")
        #expect(error.description.contains("Write failed"))
    }

    @Test("alreadyExists error description")
    func alreadyExistsErrorDescription() throws {
        let path = try File.Path("/tmp/existing")
        let error = File.Handle.Error.alreadyExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() throws {
        let path = try File.Path("/tmp/dir")
        let error = File.Handle.Error.isDirectory(path)
        #expect(error.description.contains("directory"))
    }

    @Test("alreadyClosed error description")
    func alreadyClosedErrorDescription() {
        let error = File.Handle.Error.alreadyClosed
        #expect(error.description.contains("closed"))
    }

    @Test("closeFailed error description")
    func closeFailedErrorDescription() {
        let error = File.Handle.Error.closeFailed(errno: 9, message: "Bad file descriptor")
        #expect(error.description.contains("Close failed"))
    }

    @Test("openFailed error description")
    func openFailedErrorDescription() {
        let error = File.Handle.Error.openFailed(errno: 13, message: "Permission denied")
        #expect(error.description.contains("Open failed"))
    }

    // MARK: - Error Equatable

    @Test("Handle.Error is Equatable")
    func errorEquatable() throws {
        let path = try File.Path("/tmp/test")

        #expect(File.Handle.Error.pathNotFound(path) == File.Handle.Error.pathNotFound(path))
        #expect(File.Handle.Error.invalidHandle == File.Handle.Error.invalidHandle)
        #expect(File.Handle.Error.alreadyClosed == File.Handle.Error.alreadyClosed)

        let error1 = File.Handle.Error.seekFailed(errno: 22, message: "msg")
        let error2 = File.Handle.Error.seekFailed(errno: 22, message: "msg")
        #expect(error1 == error2)
    }

    @Test("Handle.Error is Sendable")
    func errorSendable() async throws {
        let path = try File.Path("/tmp/test")
        let error = File.Handle.Error.pathNotFound(path)

        let result = await Task {
            error
        }.value

        #expect(result == error)
    }
}

// MARK: - Performance Tests

#if canImport(Foundation)
    import Foundation
#endif

extension File.Handle.Test.Performance {

    @Test(.timed(iterations: 10, warmup: 2))
    func sequentialRead1MB() throws {
        #if canImport(Foundation)
            let tempDir = try File.Path(NSTemporaryDirectory())
        #else
            let tempDir = try File.Path("/tmp")
        #endif
        let filePath = File.Path(tempDir, appending: "perf_read_1mb_\(Int.random(in: 0..<Int.max)).bin")

        // Setup: create 1MB file
        let oneMB = [UInt8](repeating: 0xAB, count: 1_000_000)
        try oneMB.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: filePath)
        }

        defer { try? File.System.Delete.delete(at: filePath) }

        // Measure sequential read
        var handle = try File.Handle.open(filePath, mode: .read)
        _ = try handle.read(count: 1_000_000)
        try handle.close()
    }

    @Test("Sequential write 1MB file", .timed(iterations: 10, warmup: 2))
    func sequentialWrite1MB() throws {
        #if canImport(Foundation)
            let tempDir = try File.Path(NSTemporaryDirectory())
        #else
            let tempDir = try File.Path("/tmp")
        #endif
        let filePath = File.Path(tempDir, appending: "perf_write_1mb_\(Int.random(in: 0..<Int.max)).bin")

        defer { try? File.System.Delete.delete(at: filePath) }

        let oneMB = [UInt8](repeating: 0xCD, count: 1_000_000)

        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .truncate, .closeOnExec]
        )
        try oneMB.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try handle.write(span)
        }
        try handle.close()
    }

    @Test("Buffer-based read into preallocated buffer", .timed(iterations: 50, warmup: 5))
    func bufferBasedRead() throws {
        #if canImport(Foundation)
            let tempDir = try File.Path(NSTemporaryDirectory())
        #else
            let tempDir = try File.Path("/tmp")
        #endif
        let filePath = File.Path(tempDir, appending: "perf_buffer_read_\(Int.random(in: 0..<Int.max)).bin")

        // Setup: create 64KB file
        let size = 64 * 1024
        let data = [UInt8](repeating: 0x42, count: size)
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: filePath)
        }

        defer { try? File.System.Delete.delete(at: filePath) }

        // Preallocate buffer (zero-allocation read pattern)
        var buffer = [UInt8](repeating: 0, count: size)

        var handle = try File.Handle.open(filePath, mode: .read)
        let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
            try handle.read(into: ptr)
        }
        #expect(bytesRead == size)
        try handle.close()
    }

    @Test("Small write throughput (4KB blocks)", .timed(iterations: 20, warmup: 3))
    func smallWriteThroughput() throws {
        #if canImport(Foundation)
            let tempDir = try File.Path(NSTemporaryDirectory())
        #else
            let tempDir = try File.Path("/tmp")
        #endif
        let filePath = File.Path(tempDir, appending: "perf_small_writes_\(Int.random(in: 0..<Int.max)).bin")

        defer { try? File.System.Delete.delete(at: filePath) }

        let blockSize = 4096
        let blocks = 256  // 1MB total
        let block = [UInt8](repeating: 0x55, count: blockSize)

        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .truncate, .closeOnExec]
        )

        for _ in 0..<blocks {
            try block.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try handle.write(span)
            }
        }

        try handle.close()
    }

    @Test("Seek operations (random access pattern)", .timed(iterations: 50, warmup: 5))
    func seekPerformance() throws {
        #if canImport(Foundation)
            let tempDir = try File.Path(NSTemporaryDirectory())
        #else
            let tempDir = try File.Path("/tmp")
        #endif
        let filePath = File.Path(tempDir, appending: "perf_seek_\(Int.random(in: 0..<Int.max)).bin")

        // Create a 1MB file for seeking
        let size = 1_000_000
        let data = [UInt8](repeating: 0x00, count: size)
        try data.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: filePath)
        }

        defer { try? File.System.Delete.delete(at: filePath) }

        var handle = try File.Handle.open(filePath, mode: .read)

        // Random-ish seek pattern
        let positions: [Int64] = [0, 500_000, 100_000, 900_000, 250_000, 750_000, 0]
        for pos in positions {
            try handle.seek(to: pos, from: .start)
        }

        try handle.close()
    }
}
