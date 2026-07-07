//
//  File.System.IO.Tests.swift
//  swift-file-system
//
//  Validates the experimental File.System.IO bundle: a second domain
//  (after swift-io's Basic test-support domain) using the
//  IO<Capabilities> + Runner architecture.
//

import Executors
import File_System
import File_System_Test_Support
import IO_Primitives
@_spi(Syscall) import Kernel
import Kernel_Test_Support
import Memory_Primitives
import Span_Raw_Primitives
import Testing

@Suite
struct `File.System.IO — smoke tests` {

    @Test
    func `open → stat → close via blocking strategy`() async throws {
        let executor = Kernel.Thread.Executor()
        defer { executor.shutdown() }

        let io: IO<File.System.IO.Capabilities> = .blocking(on: executor)

        let pathString = Kernel.Temporary.filePath(prefix: "fs-io-test")
        let path = try File.Path(pathString)

        // Create the file via kernel open (independent of io.open), then
        // exercise io.stat + io.close on it.
        let fd = try Kernel.File.Open.open(
            path: path.kernelPath,
            mode: .readWrite,
            options: [.create, .execClose],
            permissions: Kernel.File.Permissions(rawValue: 0o644)
        )
        defer { try? Kernel.File.Delete.delete(path.kernelPath) }

        let stats = try await io.stat(path)
        #expect(stats.size.underlying == 0)

        await io.close(consume fd)
    }

    @Test
    func `default() chain returns a working IO on the host`() async throws {
        let executor = Kernel.Thread.Executor()
        defer { executor.shutdown() }
        let io: IO<File.System.IO.Capabilities> = .default(on: executor)

        // Round-trip stat of an empty temp file through whichever
        // strategy default() selected on this host.
        let pathString = Kernel.Temporary.filePath(prefix: "fs-io-default")
        let path = try File.Path(pathString)
        defer { try? Kernel.File.Delete.delete(path.kernelPath) }
        let fd = try Kernel.File.Open.open(
            path: path.kernelPath,
            mode: .readWrite,
            options: [.create, .execClose],
            permissions: Kernel.File.Permissions(rawValue: 0o644)
        )

        let stats = try await io.stat(path)
        #expect(stats.size.underlying == 0)

        await io.close(consume fd)
    }

    @Test
    func `write → stat via blocking strategy`() async throws {
        let executor = Kernel.Thread.Executor()
        defer { executor.shutdown() }

        let io: IO<File.System.IO.Capabilities> = .blocking(on: executor)

        let pathString = Kernel.Temporary.filePath(prefix: "fs-io-rw")
        let path = try File.Path(pathString)
        defer { try? Kernel.File.Delete.delete(path.kernelPath) }

        let fd = try Kernel.File.Open.open(
            path: path.kernelPath,
            mode: .readWrite,
            options: [.create, .truncate, .execClose],
            permissions: Kernel.File.Permissions(rawValue: 0o644)
        )

        let payload: [Byte] = [0xDE, 0xAD, 0xBE, 0xEF]
        let writePtr = unsafe UnsafeMutableRawBufferPointer.allocate(
            byteCount: payload.count,
            alignment: 1
        )
        defer { unsafe writePtr.deallocate() }
        for (i, byte) in payload.enumerated() { unsafe writePtr[i] = byte.underlying }

        let written = try await io.write(
            to: fd,
            from: unsafe .init(UnsafeRawBufferPointer(writePtr))
        )
        #expect(written == payload.count)

        let stats = try await io.stat(path)
        #expect(stats.size.underlying == UInt64(payload.count))

        await io.close(consume fd)
    }
}
