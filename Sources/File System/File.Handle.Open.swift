public import Kernel

extension File.Handle {

    public struct Open: Swift.Sendable {

        public let path: File.Path

        public let options: Kernel.File.Open.Options

        @usableFromInline
        internal init(path: File.Path, options: Kernel.File.Open.Options) {
            self.path = path
            self.options = options
        }
    }
}

extension File.Handle.Open {

    public enum Error<ClosureError: Swift.Error>: Swift.Error, Sendable {

        case open(Kernel.File.Open.Error)

        case operation(ClosureError)

        case close(Kernel.Close.Error)
    }
}

extension File.Handle.Open {

    @usableFromInline
    internal func scoped<Result, E: Swift.Error>(
        mode: Kernel.File.Open.Mode,
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var handle: File.Handle
        do throws(Kernel.File.Open.Error) {
            handle = try File.Handle.open(path, mode: mode, options: options)
        } catch {
            throw .open(error)
        }

        let result: Result
        do throws(E) {
            result = try body(&handle)
        } catch {
            do throws(Kernel.Close.Error) {
                try handle.close()
            } catch {

            }
            throw .operation(error)
        }

        do throws(Kernel.Close.Error) {
            try handle.close()
        } catch {
            throw .close(error)
        }
        return result
    }

    @usableFromInline
    internal func scoped<Result, E: Swift.Error>(
        mode: Kernel.File.Open.Mode,
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        var handle: File.Handle
        do throws(Kernel.File.Open.Error) {
            handle = try File.Handle.open(path, mode: mode, options: options)
        } catch {
            throw .open(error)
        }

        let result: Result
        do throws(E) {
            result = try await body(&handle)
        } catch {
            do throws(Kernel.Close.Error) {
                try handle.close()
            } catch {

            }
            throw .operation(error)
        }

        do throws(Kernel.Close.Error) {
            try handle.close()
        } catch {
            throw .close(error)
        }
        return result
    }
}

extension File.Handle.Open {

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try read(body)
    }

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await read(body)
    }
}

extension File.Handle.Open {

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.read, body)
    }

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.read, body)
    }
}

extension File.Handle.Open {

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.write, body)
    }

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.write, body)
    }
}

extension File.Handle.Open {

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var appendOptions = options
        appendOptions.insert(.append)
        let appendOpen = File.Handle.Open(path: path, options: appendOptions)
        return try appendOpen.scoped(mode: .write, body)
    }

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        var appendOptions = options
        appendOptions.insert(.append)
        let appendOpen = File.Handle.Open(path: path, options: appendOptions)
        return try await appendOpen.scoped(mode: .write, body)
    }
}

extension File.Handle.Open {

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: .readWrite, body)
    }

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: .readWrite, body)
    }
}

extension File.Handle {

    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        options: Kernel.File.Open.Options = []
    ) -> Open {
        Open(path: copy path, options: options)
    }
}
