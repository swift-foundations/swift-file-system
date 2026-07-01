//
//  IO+File.System.swift
//  swift-file-system
//
//  Labeled forwarding methods on `IO<File.System.IO.Capabilities>`.
//  Callers write `io.open(path, mode: .read)` instead of the positional
//  `io.capabilities.open(path, .read)`.
//

public import IO
public import Kernel
public import Memory_Primitives
public import Span_Raw_Primitives

extension IO where Capabilities == File.System.IO.Capabilities {

    /// Open `path` in the given mode.
    @inlinable
    public func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode
    ) async throws(File.System.IO.Error) -> Kernel.Descriptor {
        try await capabilities.open(path, mode)
    }

    /// Read file metadata for `path`.
    @inlinable
    public func stat(
        _ path: borrowing File.Path
    ) async throws(File.System.IO.Error) -> Kernel.File.Stats {
        try await capabilities.stat(path)
    }

    /// Read bytes from `fd` into `buffer`.
    @inlinable
    public func read(
        from fd: borrowing Kernel.Descriptor,
        into buffer: Span.Raw.Mutable
    ) async throws(File.System.IO.Error) -> Int {
        try await capabilities.read(fd, buffer)
    }

    /// Write bytes from `buffer` to `fd`.
    @inlinable
    public func write(
        to fd: borrowing Kernel.Descriptor,
        from buffer: Span.Raw
    ) async throws(File.System.IO.Error) -> Int {
        try await capabilities.write(fd, buffer)
    }

    /// Close `fd`.
    @inlinable
    public func close(_ fd: consuming Kernel.Descriptor) async {
        await capabilities.close(consume fd)
    }

    /// The `UnownedSerialExecutor` this bundle is pinned to.
    @inlinable
    public var unownedExecutor: UnownedSerialExecutor {
        runner.executor()
    }
}
