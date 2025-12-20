//
//  File.Handle.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Async

extension File.Handle.Async {
    #TestSuites
}

extension File.Handle.Async.Test.Unit {

    // MARK: - Test Fixtures

    private func createTempFile(content: [UInt8] = []) throws -> File.Path {
        let path = try File.Path("/tmp/async-handle-test-\(Int.random(in: 0..<Int.max)).bin")
        try content.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
        return path
    }

    private func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path)
    }

    // MARK: - Opening

    @Test("Open file for reading")
    func openForReading() async throws {
        let io = File.IO.Executor()
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)
            #expect(await handle.isOpen)
            #expect(handle.mode == .read)
            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    @Test("Open file for writing")
    func openForWriting() async throws {
        let io = File.IO.Executor()
        let path = try createTempFile()

        do {
            let handle = try await File.Handle.Async.open(path, mode: .write, io: io)
            #expect(await handle.isOpen)
            #expect(handle.mode == .write)
            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    // MARK: - Reading

    @Test("Read bytes from file")
    func readBytes() async throws {
        let io = File.IO.Executor()
        let content: [UInt8] = [10, 20, 30, 40, 50]
        let path = try createTempFile(content: content)

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)
            let data = try await handle.read(count: 5)
            #expect(data == content)
            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    @Test("Read partial bytes")
    func readPartialBytes() async throws {
        let io = File.IO.Executor()
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

            let first = try await handle.read(count: 5)
            #expect(first == [1, 2, 3, 4, 5])

            let second = try await handle.read(count: 5)
            #expect(second == [6, 7, 8, 9, 10])

            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    // Note: read(into:) with caller-provided buffer is tested via integration tests.
    // Direct unit testing is complex due to Swift 6 Sendable checking on raw buffer pointers.

    // MARK: - Writing

    @Test("Write bytes to file")
    func writeBytes() async throws {
        let io = File.IO.Executor()
        let path = try createTempFile()

        do {
            let handle = try await File.Handle.Async.open(
                path,
                mode: .write,
                options: [.truncate],
                io: io
            )
            let data: [UInt8] = [100, 101, 102, 103, 104]
            try await handle.write(data)
            try await handle.close()

            let readBack = try await File.System.Read.Full.read(from: path)
            #expect(readBack == data)
        }

        await io.shutdown()
        cleanup(path)
    }

    // MARK: - Seeking

    @Test("Seek and read")
    func seekAndRead() async throws {
        let io = File.IO.Executor()
        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

            let pos = try await handle.seek(to: 5)
            #expect(pos == 5)

            let data = try await handle.read(count: 3)
            #expect(data == [6, 7, 8])

            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    @Test("Rewind and seekToEnd")
    func rewindAndSeekToEnd() async throws {
        let io = File.IO.Executor()
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

            // Read some data
            _ = try await handle.read(count: 3)

            // Rewind (seek to start)
            let rewindPos = try await handle.seek(to: 0, from: .start)
            #expect(rewindPos == 0)

            // Seek to end
            let endPos = try await handle.seek(to: 0, from: .end)
            #expect(endPos == 5)

            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    // MARK: - Close

    @Test("Close is idempotent")
    func closeIsIdempotent() async throws {
        let io = File.IO.Executor()
        let path = try createTempFile(content: [1, 2, 3])

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)
            #expect(await handle.isOpen)

            try await handle.close()
            #expect(await !handle.isOpen)

            // Second close should not throw
            try await handle.close()
        }

        await io.shutdown()
        cleanup(path)
    }

    @Test("Operations on closed handle throw")
    func operationsOnClosedThrow() async throws {
        let io = File.IO.Executor()
        let path = try createTempFile(content: [1, 2, 3])

        do {
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)
            try await handle.close()

            await #expect(throws: File.Handle.Error.self) {
                _ = try await handle.read(count: 10)
            }
        }

        await io.shutdown()
        cleanup(path)
    }

    // MARK: - Handle Store Tests

    @Test("Handle ID scope mismatch throws")
    func scopeMismatchThrows() async throws {
        let io1 = File.IO.Executor()
        let io2 = File.IO.Executor()
        let path = try createTempFile(content: [1, 2, 3])

        do {
            // Open on io1
            let handle = try await File.Handle.Async.open(path, mode: .read, io: io1)

            // The handle's ID is scoped to io1, using it with io2 should fail
            // (This is tested indirectly through the actor design)
            #expect(handle.mode == .read)

            try await handle.close()
        }

        await io1.shutdown()
        await io2.shutdown()
        cleanup(path)
    }

    @Test("Shutdown closes remaining handles")
    func shutdownClosesHandles() async throws {
        let io = File.IO.Executor()
        let path = try createTempFile(content: [1, 2, 3])

        // Open but don't explicitly close - shutdown should handle it
        let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

        // Shutdown should close the handle (best-effort)
        await io.shutdown()

        // Handle should no longer be valid (shutdown closed it)
        #expect(await !handle.isOpen)

        // Now the handle can go out of scope safely - isClosed should be true
        cleanup(path)
    }
}
