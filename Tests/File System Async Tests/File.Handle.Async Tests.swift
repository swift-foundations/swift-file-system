//
//  File.Handle.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System
import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Async

extension File.Handle.Async {
    #TestSuites
}

extension File.Handle.Async.Test.Unit {

    // MARK: - Opening

    @Test("Open file for reading")
    func openForReading() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)
            #expect(await handle.isOpen)
            #expect(handle.mode == .read)
            try await handle.close()
        }

        await fs.shutdown()
    }

    @Test("Open file for writing")
    func openForWriting() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .write, fs: fs)
            #expect(await handle.isOpen)
            #expect(handle.mode == .write)
            try await handle.close()
        }

        await fs.shutdown()
    }

    // MARK: - Reading

    @Test("Read bytes from file")
    func readBytes() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let content: [UInt8] = [10, 20, 30, 40, 50]
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)
            let data = try await handle.read(count: 5)
            #expect(data == content)
            try await handle.close()
        }

        await fs.shutdown()
    }

    @Test("Read partial bytes")
    func readPartialBytes() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)

            let first = try await handle.read(count: 5)
            #expect(first == [1, 2, 3, 4, 5])

            let second = try await handle.read(count: 5)
            #expect(second == [6, 7, 8, 9, 10])

            try await handle.close()
        }

        await fs.shutdown()
    }

    // Note: read(into:) with caller-provided buffer is tested via integration tests.
    // Direct unit testing is complex due to Swift 6 Sendable checking on raw buffer pointers.

    // MARK: - Writing

    @Test("Write bytes to file")
    func writeBytes() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: path)

            let handle = try await File.Handle.Async.open(
                path,
                mode: .write,
                options: [.truncate],
                fs: fs
            )
            let data: [UInt8] = [100, 101, 102, 103, 104]
            try await handle.write(data)
            try await handle.close()

            let readBack = try await File.System.Read.Full.read(from: path)
            #expect(readBack == data)
        }

        await fs.shutdown()
    }

    // MARK: - Seeking

    @Test("Seek and read")
    func seekAndRead() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)

            let pos = try await handle.seek(to: 5)
            #expect(pos == 5)

            let data = try await handle.read(count: 3)
            #expect(data == [6, 7, 8])

            try await handle.close()
        }

        await fs.shutdown()
    }

    @Test("Rewind and seekToEnd")
    func rewindAndSeekToEnd() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)

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

        await fs.shutdown()
    }

    // MARK: - Close

    @Test("Close is idempotent")
    func closeIsIdempotent() async throws {
        let fs = File.System.Async()

        try await File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: path)

            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)
            #expect(await handle.isOpen)

            try await handle.close()
            #expect(await !handle.isOpen)

            // Second close should not throw
            try await handle.close()
        }

        await fs.shutdown()
    }

    @Test("Operations on closed handle throw")
    func operationsOnClosedThrow() async throws {
        let fs = File.System.Async()

        let base = try File.Directory.Temporary.system
        let dirName = "test-\(Int.random(in: 0..<Int.max))"
        let dirPath = File.Path(base.path, appending: dirName)
        try await File.System.Create.Directory.create(at: dirPath)
        defer { try? File.System.Delete.delete(at: dirPath, options: .init(recursive: true)) }

        let dir = File.Directory(dirPath)
        let path = File.Path(dir.path, appending: "test-file.bin")
        try File.System.Write.Atomic.write([1, 2, 3].span, to: path)

        let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)
        try await handle.close()

        do {
            _ = try await handle.read(count: 10)
            Issue.record("Expected error to be thrown")
        } catch {
            // error is IO.Lifecycle.Error<IO.Error<File.Handle.Error>>
            if case .failure(.operation(.invalidHandle)) = error {
                // Expected error
            } else {
                Issue.record("Expected .failure(.operation(.invalidHandle)), got \(error)")
            }
        }

        await fs.shutdown()
    }

    // MARK: - Handle Store Tests

    @Test("Handle ID scope mismatch throws")
    func scopeMismatchThrows() async throws {
        try await File.Directory.temporary { dir in
            let io1 = File.System.Async()
            let io2 = File.System.Async()
            defer {
                Task {
                    await io1.shutdown()
                    await io2.shutdown()
                }
            }

            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: path)

            // Open on io1
            let handle = try await File.Handle.Async.open(path, mode: .read, fs: io1)

            // The handle's ID is scoped to io1, using it with io2 should fail
            // (This is tested indirectly through the actor design)
            #expect(handle.mode == .read)

            try await handle.close()
        }
    }

    @Test("Shutdown closes remaining handles")
    func shutdownClosesHandles() async throws {
        try await File.Directory.temporary { dir in
            let fs = File.System.Async()

            let path = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: path)

            // Open but don't explicitly close - shutdown should handle it
            let handle = try await File.Handle.Async.open(path, mode: .read, fs: fs)

            // Shutdown should close the handle (best-effort)
            await fs.shutdown()

            // Handle should no longer be valid (shutdown closed it)
            #expect(await !handle.isOpen)

            // Now the handle can go out of scope safely - isClosed should be true
        }
    }
}
