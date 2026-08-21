public import IO
public import Kernel
import Memory_Primitives
public import Span_Raw_Primitives

extension IO where Capabilities == File.System.IO.Capabilities {

    @inlinable
    public func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode
    ) async throws(File.System.IO.Error) -> Kernel.Descriptor {
        try await capabilities.open(path, mode)
    }

    @inlinable
    public func stat(
        _ path: borrowing File.Path
    ) async throws(File.System.IO.Error) -> Kernel.File.Stats {
        try await capabilities.stat(path)
    }

    @inlinable
    public func read(
        from fd: borrowing Kernel.Descriptor,
        into buffer: Span.Raw.Mutable
    ) async throws(File.System.IO.Error) -> Int {
        try await capabilities.read(fd, buffer)
    }

    @inlinable
    public func write(
        to fd: borrowing Kernel.Descriptor,
        from buffer: Span.Raw
    ) async throws(File.System.IO.Error) -> Int {
        try await capabilities.write(fd, buffer)
    }

    @inlinable
    public func close(_ fd: consuming Kernel.Descriptor) async {
        await capabilities.close(consume fd)
    }

    @inlinable
    public var unownedExecutor: UnownedSerialExecutor {
        unsafe runner.executor()
    }
}
