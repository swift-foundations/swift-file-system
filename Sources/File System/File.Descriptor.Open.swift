public import Kernel

extension File.Descriptor {

    public struct Open: Sendable {

        public let path: File.Path

        public let options: Kernel.File.Open.Options

        @usableFromInline
        internal init(path: File.Path, options: Kernel.File.Open.Options) {
            self.path = path
            self.options = options
        }
    }
}

extension File.Descriptor.Open {

    public enum Error<ClosureError: Swift.Error>: Swift.Error, Sendable {

        case open(Kernel.File.Open.Error)

        case operation(ClosureError)

        case close(Kernel.Close.Error)
    }
}

extension File.Descriptor.Open {

    @usableFromInline
    internal func scoped<Result, E: Swift.Error>(
        mode: Kernel.File.Open.Mode,
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var descriptor: File.Descriptor
        do throws(Kernel.File.Open.Error) {
            descriptor = try File.Descriptor.open(path, mode: mode, options: options)
        } catch {
            throw .open(error)
        }

        let result: Result
        do throws(E) {
            result = try body(&descriptor)
        } catch {

            _ = consume descriptor
            throw .operation(error)
        }

        do throws(Kernel.Close.Error) {
            try descriptor.close()
        } catch {
            throw .close(error)
        }
        return result
    }

    @usableFromInline
    internal func scoped<Result, E: Swift.Error>(
        mode: Kernel.File.Open.Mode,
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        var descriptor: File.Descriptor
        do throws(Kernel.File.Open.Error) {
            descriptor = try File.Descriptor.open(path, mode: mode, options: options)
        } catch {
            throw .open(error)
        }

        let result: Result
        do throws(E) {
            result = try await body(&descriptor)
        } catch {

            _ = consume descriptor
            throw .operation(error)
        }

        do throws(Kernel.Close.Error) {
            try descriptor.close()
        } catch {
            throw .close(error)
        }
        return result
    }
}

extension File.Descriptor.Open {

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try read(body)
    }

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await read(body)
    }
}

extension File.Descriptor.Open {

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.read, body)
    }

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.read, body)
    }
}

extension File.Descriptor.Open {

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.write, body)
    }

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.write, body)
    }
}

extension File.Descriptor.Open {

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var opts = options
        opts.insert(.append)
        return try File.Descriptor.Open(path: path, options: opts).scoped(
            mode: Kernel.File.Open.Mode.write,
            body
        )
    }

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        var opts = options
        opts.insert(.append)
        return try await File.Descriptor.Open(path: path, options: opts).scoped(
            mode: Kernel.File.Open.Mode.write,
            body
        )
    }
}

extension File.Descriptor.Open {

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: .readWrite, body)
    }

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: .readWrite, body)
    }
}

extension File.Descriptor {

    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        options: Kernel.File.Open.Options = []
    ) -> Open {
        Open(path: copy path, options: options)
    }
}
