//
//  File.Handle Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

@testable import File_System_Primitives

extension File.Handle {
    #TestSuites
}

extension File.Handle.Test.Unit {
    // MARK: - Opening

    @Test("Open file for reading")
    func openForReading() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .read)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .read)
            try handle.close()
        }
    }

    @Test("Open file for writing")
    func openForWriting() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .write)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .write)
            try handle.close()
        }
    }

    @Test("Open file for read/write")
    func openForReadWrite() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: [.read, .write])
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == [.read, .write])
            try handle.close()
        }
    }

    @Test("Open file for append")
    func openForAppend() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .append)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .append)
            try handle.close()
        }
    }

    @Test("Open with create option")
    func openWithCreate() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")

            let handle = try File.Handle.open(filePath, mode: .write, options: [.create])
            let isValid = handle.isValid
            #expect(isValid)
            #expect(File.System.Stat.exists(at: filePath))
            try handle.close()
        }
    }

    @Test("Open non-existing file throws pathNotFound")
    func openNonExisting() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "non-existing.txt")

            #expect(throws: File.Handle.Error.self) {
                _ = try File.Handle.open(filePath, mode: .read)
            }
        }
    }

    // MARK: - Reading

    @Test("Read bytes from file")
    func readBytes() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [10, 20, 30, 40, 50]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)
            let readData = try handle.read(count: 5)
            #expect(readData == content)
            try handle.close()
        }
    }

    @Test("Read partial bytes")
    func readPartialBytes() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let firstPart = try handle.read(count: 5)
            #expect(firstPart == [1, 2, 3, 4, 5])

            let secondPart = try handle.read(count: 5)
            #expect(secondPart == [6, 7, 8, 9, 10])
            try handle.close()
        }
    }

    @Test("Read at EOF returns empty")
    func readAtEOF() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            _ = try handle.read(count: 3)  // Read all
            let atEOF = try handle.read(count: 10)
            #expect(atEOF.isEmpty)
            try handle.close()
        }
    }

    @Test("Read more than available returns available")
    func readMoreThanAvailable() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let readData = try handle.read(count: 100)
            #expect(readData == content)
            try handle.close()
        }
    }

    // MARK: - Writing

    @Test("Write bytes to file")
    func writeBytes() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

            let data: [UInt8] = [100, 101, 102, 103, 104]
            try handle.write(data.span)
            try handle.close()

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack == data)
        }
    }

    @Test("Write empty data")
    func writeEmpty() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

            let data: [UInt8] = []
            try handle.write(data.span)
            try handle.close()

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack.isEmpty)
        }
    }

    // MARK: - Seeking

    @Test("Seek from start")
    func seekFromStart() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let newPos = try handle.seek(to: 5, from: .start)
            #expect(newPos == 5)

            let readData = try handle.read(count: 3)
            #expect(readData == [6, 7, 8])
            try handle.close()
        }
    }

    @Test("Seek from current")
    func seekFromCurrent() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            _ = try handle.read(count: 3)  // Position at 3
            let newPos = try handle.seek(to: 2, from: .current)  // Now at 5
            #expect(newPos == 5)

            let readData = try handle.read(count: 1)
            #expect(readData == [6])
            try handle.close()
        }
    }

    @Test("Seek from end")
    func seekFromEnd() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let newPos = try handle.seek(to: -3, from: .end)
            #expect(newPos == 7)

            let readData = try handle.read(count: 3)
            #expect(readData == [8, 9, 10])
            try handle.close()
        }
    }

    @Test("Get current position")
    func getCurrentPosition() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let pos1 = try handle.seek(to: 0, from: .current)
            #expect(pos1 == 0)
            _ = try handle.read(count: 3)
            let pos2 = try handle.seek(to: 0, from: .current)
            #expect(pos2 == 3)
            try handle.close()
        }
    }

    // MARK: - Sync

    @Test("Sync flushes to disk")
    func syncToDisk() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")
            var handle = try File.Handle.open(filePath, mode: .write, options: [.create])

            let data: [UInt8] = [1, 2, 3]
            try handle.write(data.span)
            try handle.sync()
            try handle.close()

            // File should exist and have content
            #expect(File.System.Stat.exists(at: filePath))
        }
    }

    // MARK: - Error descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.Handle.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
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
        let error = File.Handle.Error.seekFailed(offset: -1, origin: .start, errno: 22, message: "Invalid argument")
        #expect(error.description.contains("Seek to -1 from start failed"))
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
        let path = File.Path("/tmp/existing")
        let error = File.Handle.Error.alreadyExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() throws {
        let path = File.Path("/tmp/dir")
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
        let path = File.Path("/tmp/test")

        #expect(File.Handle.Error.pathNotFound(path) == File.Handle.Error.pathNotFound(path))
        #expect(File.Handle.Error.invalidHandle == File.Handle.Error.invalidHandle)
        #expect(File.Handle.Error.alreadyClosed == File.Handle.Error.alreadyClosed)

        let error1 = File.Handle.Error.seekFailed(offset: 100, origin: .current, errno: 22, message: "msg")
        let error2 = File.Handle.Error.seekFailed(offset: 100, origin: .current, errno: 22, message: "msg")
        #expect(error1 == error2)
    }

    @Test("Handle.Error is Sendable")
    func errorSendable() async throws {
        let path = File.Path("/tmp/test")
        let error = File.Handle.Error.pathNotFound(path)

        let result = await Task {
            error
        }.value

        #expect(result == error)
    }
}

// MARK: - Positional Write Tests (_pwrite)

extension File.Handle.Test.Unit {
    @Test("_pwrite writes at absolute offset")
    func pwriteAtAbsoluteOffset() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwrite_test.bin")

            // Create file and write initial content
            var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .truncate])

            // Write "AAAA" at offset 0
            let bytes1: [UInt8] = [0x41, 0x41, 0x41, 0x41]
            try bytes1.withUnsafeBytes { buffer in
                let written = try handle._pwrite(buffer, at: 0)
                #expect(written == 4)
            }

            // Write "BBBB" at offset 4
            let bytes2: [UInt8] = [0x42, 0x42, 0x42, 0x42]
            try bytes2.withUnsafeBytes { buffer in
                let written = try handle._pwrite(buffer, at: 4)
                #expect(written == 4)
            }

            try handle.close()

            // Verify content: should be "AAAABBBB"
            let content = try File.System.Read.Full.read(from: filePath)
            #expect(content == [0x41, 0x41, 0x41, 0x41, 0x42, 0x42, 0x42, 0x42])
        }
    }

    @Test("_pwrite does not advance file position")
    func pwriteDoesNotAdvancePosition() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwrite_pos_test.bin")

            // Create a file with some initial content for seeking
            let initial: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: [.read, .write])

            // Get initial position
            let pos1 = try handle.seek(to: 0, from: .current)
            #expect(pos1 == 0)

            // Write at offset 4 using _pwrite
            let bytes: [UInt8] = [0xFF, 0xFF]
            try bytes.withUnsafeBytes { buffer in
                _ = try handle._pwrite(buffer, at: 4)
            }

            // Position should still be 0 (not advanced)
            let pos2 = try handle.seek(to: 0, from: .current)
            #expect(pos2 == 0)

            try handle.close()
        }
    }

    @Test("_pwrite overwrites at specified offset")
    func pwriteOverwrites() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwrite_overwrite.bin")

            // Create file with "XXXXXXXX"
            let initial: [UInt8] = [0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58]
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write)

            // Overwrite bytes 2-5 with "YYYY"
            let bytes: [UInt8] = [0x59, 0x59, 0x59, 0x59]
            try bytes.withUnsafeBytes { buffer in
                _ = try handle._pwrite(buffer, at: 2)
            }

            try handle.close()

            // Should be "XXYYYYXX"
            let content = try File.System.Read.Full.read(from: filePath)
            #expect(content == [0x58, 0x58, 0x59, 0x59, 0x59, 0x59, 0x58, 0x58])
        }
    }

    @Test("_pwrite with empty buffer returns 0")
    func pwriteEmptyBuffer() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwrite_empty.bin")

            var handle = try File.Handle.open(filePath, mode: .write, options: [.create])

            let empty: [UInt8] = []
            try empty.withUnsafeBytes { buffer in
                let written = try handle._pwrite(buffer, at: 0)
                #expect(written == 0)
            }

            try handle.close()
        }
    }

    @Test("_pwriteAll writes all bytes")
    func pwriteAllWritesAllBytes() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwriteall_test.bin")

            var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .truncate])

            // Write 10KB of data using _pwriteAll
            let data = [UInt8](repeating: 0xAB, count: 10_000)
            try data.withUnsafeBytes { buffer in
                try handle._pwriteAll(buffer, at: 0)
            }

            try handle.close()

            // Verify all bytes written
            let content = try File.System.Read.Full.read(from: filePath)
            #expect(content.count == 10_000)
            #expect(content.allSatisfy { $0 == 0xAB })
        }
    }

    @Test("_pwriteAll at non-zero offset")
    func pwriteAllAtOffset() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "pwriteall_offset.bin")

            // Create file with zeros
            let initial = [UInt8](repeating: 0, count: 100)
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write)

            // Write at offset 50
            let data: [UInt8] = [1, 2, 3, 4, 5]
            try data.withUnsafeBytes { buffer in
                try handle._pwriteAll(buffer, at: 50)
            }

            try handle.close()

            // Verify
            let content = try File.System.Read.Full.read(from: filePath)
            #expect(content[50] == 1)
            #expect(content[51] == 2)
            #expect(content[52] == 3)
            #expect(content[53] == 4)
            #expect(content[54] == 5)
        }
    }

    #if !os(Windows)
    @Test("_pwrite ESPIPE fallback at offset 0")
    func pwriteEspipeFallbackOffsetZero() throws {
        // Create a pipe - pwrite will fail with ESPIPE
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            throw File.Handle.Error.openFailed(errno: errno, message: "Failed to create pipe")
        }

        defer {
            close(fds[0])
            close(fds[1])
        }

        // Create a handle for the write end
        let writeDescriptor = File.Descriptor(__unchecked: fds[1])
        var handle = File.Handle(
            descriptor: writeDescriptor,
            mode: .write,
            path: File.Path("/dev/pipe")
        )

        // Write at offset 0 should succeed (falls back to write)
        let bytes: [UInt8] = [0x41, 0x42, 0x43]
        try bytes.withUnsafeBytes { buffer in
            let written = try handle._pwrite(buffer, at: 0)
            #expect(written == 3)
        }

        // Read from pipe to verify
        var readBuffer = [UInt8](repeating: 0, count: 3)
        let bytesRead = read(fds[0], &readBuffer, 3)
        #expect(bytesRead == 3)
        #expect(readBuffer == bytes)

        // Don't close handle - descriptor will be closed by defer
        _ = consume handle
    }

    @Test("_pwrite ESPIPE throws at non-zero offset")
    func pwriteEspipeThrowsNonZeroOffset() throws {
        // Create a pipe
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            throw File.Handle.Error.openFailed(errno: errno, message: "Failed to create pipe")
        }

        defer {
            close(fds[0])
            close(fds[1])
        }

        let writeDescriptor = File.Descriptor(__unchecked: fds[1])
        var handle = File.Handle(
            descriptor: writeDescriptor,
            mode: .write,
            path: File.Path("/dev/pipe")
        )

        // Write at offset > 0 should throw (can't seek on pipe)
        let bytes: [UInt8] = [0x41, 0x42, 0x43]
        #expect(throws: File.Handle.Error.self) {
            try bytes.withUnsafeBytes { buffer in
                _ = try handle._pwrite(buffer, at: 100)
            }
        }

        _ = consume handle
    }
    #endif
}

// MARK: - Performance Tests

extension File.Handle.Test.Performance {

    @Test(.timed(iterations: 10, warmup: 2))
    func sequentialRead1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_read_1mb_\(Int.random(in: 0..<Int.max)).bin"
        )

        // Setup: create 1MB file
        let oneMB = [UInt8](repeating: 0xAB, count: 1_000_000)
        try File.System.Write.Atomic.write(oneMB.span, to: filePath)

        defer { try? File.System.Delete.delete(at: filePath) }

        // Measure sequential read
        var handle = try File.Handle.open(filePath, mode: .read)
        _ = try handle.read(count: 1_000_000)
        try handle.close()
    }

    @Test("Sequential write 1MB file", .timed(iterations: 10, warmup: 2))
    func sequentialWrite1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_write_1mb_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        let oneMB = [UInt8](repeating: 0xCD, count: 1_000_000)

        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .truncate, .closeOnExec]
        )
        try handle.write(oneMB.span)
        try handle.close()
    }

    @Test("Buffer-based read into preallocated buffer", .timed(iterations: 50, warmup: 5))
    func bufferBasedRead() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_buffer_read_\(Int.random(in: 0..<Int.max)).bin"
        )

        // Setup: create 64KB file
        let size = 64 * 1024
        let data = [UInt8](repeating: 0x42, count: size)
        try File.System.Write.Atomic.write(data.span, to: filePath)

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
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_small_writes_\(Int.random(in: 0..<Int.max)).bin"
        )

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
            try handle.write(block.span)
        }

        try handle.close()
    }

    @Test("Seek operations (random access pattern)", .timed(iterations: 50, warmup: 5))
    func seekPerformance() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(td.path, appending: "perf_seek_\(Int.random(in: 0..<Int.max)).bin")

        // Create a 1MB file for seeking
        let size = 1_000_000
        let data = [UInt8](repeating: 0x00, count: size)
        try File.System.Write.Atomic.write(data.span, to: filePath)

        defer { try? File.System.Delete.delete(at: filePath) }

        var handle = try File.Handle.open(filePath, mode: .read)

        // Random-ish seek pattern
        let positions: [Int64] = [0, 500_000, 100_000, 900_000, 250_000, 750_000, 0]
        for pos in positions {
            try handle.seek(to: pos, from: .start)
        }

        try handle.close()
    }

    @Test("Positional write streaming (1MB chunks)", .timed(iterations: 10, warmup: 2))
    func pwriteStreamingPerformance() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_pwrite_streaming_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        let chunkSize = 1_000_000  // 1MB chunks
        let chunks = 100  // 100MB total
        let chunk = [UInt8](repeating: 0xAB, count: chunkSize)

        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .truncate, .closeOnExec]
        )

        var offset: Int64 = 0
        for _ in 0..<chunks {
            try chunk.withUnsafeBytes { buffer in
                try handle._pwriteAll(buffer, at: offset)
            }
            offset += Int64(chunkSize)
        }

        try handle.close()
    }

    @Test("Sequential write streaming (1MB chunks) for comparison", .timed(iterations: 10, warmup: 2))
    func sequentialStreamingPerformance() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_seq_streaming_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        let chunkSize = 1_000_000  // 1MB chunks
        let chunks = 100  // 100MB total
        let chunk = [UInt8](repeating: 0xAB, count: chunkSize)

        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .truncate, .closeOnExec]
        )

        for _ in 0..<chunks {
            try handle.write(chunk.span)
        }

        try handle.close()
    }
}
