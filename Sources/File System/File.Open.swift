public import Kernel

extension File {

    public struct Open: Sendable {

        @usableFromInline
        internal let _open: File.Handle.Open

        @usableFromInline
        internal init(path: File.Path, options: Kernel.File.Open.Options) {
            self._open = File.Handle.Open(path: path, options: options)
        }
    }
}

extension File.Open {

    @inlinable
    public var path: File.Path { _open.path }

    @inlinable
    public var options: Kernel.File.Open.Options { _open.options }
}

extension File.Open {

    public typealias Error<E: Swift.Error> = File.Handle.Open.Error<E>
}

extension File.Open {

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try _open.read(body)
    }
}

extension File.Open {

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try _open.read(body)
    }
}

extension File.Open {

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try _open.write(body)
    }
}

extension File.Open {

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try _open.appending(body)
    }
}

extension File.Open {

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try _open.readWrite(body)
    }
}

extension File.Open {

    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await _open.read(body)
    }

    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await _open.read(body)
    }

    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await _open.write(body)
    }

    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await _open.appending(body)
    }

    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await _open.readWrite(body)
    }
}

extension File {

    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        options: Kernel.File.Open.Options = []
    ) -> Open {
        Open(path: copy path, options: options)
    }
}

extension File {

    public var open: Open {
        Open(path: path, options: [])
    }

    @inlinable
    public func open(options: Kernel.File.Open.Options) -> Open {
        Open(path: path, options: options)
    }
}
