//
//  File.Descriptor.Open.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Kernel

// MARK: - Open Namespace

extension File.Descriptor {
    /// Namespace for scoped file descriptor open operations.
    ///
    /// This provides an ergonomic API for opening files with automatic cleanup.
    /// Use `File.Descriptor.open(path)` to get an `Open` instance, then call it
    /// directly for read access, or use `.write`, `.appending`, or `.readWrite`
    /// for other access modes.
    ///
    /// ## Example
    /// ```swift
    /// // Read-only (default)
    /// let result = try File.Descriptor.open(path) { descriptor in
    ///     // use descriptor
    /// }
    ///
    /// // Write access
    /// try File.Descriptor.open(path).write { descriptor in
    ///     // write to descriptor
    /// }
    /// ```
    public struct Open: Sendable {
        /// The path to open.
        public let path: File.Path
        /// Options for opening.
        public let options: Kernel.File.Open.Options

        /// Creates an Open instance.
        @usableFromInline
        internal init(path: File.Path, options: Kernel.File.Open.Options) {
            self.path = path
            self.options = options
        }
    }
}

// MARK: - Scoped Error Type

extension File.Descriptor.Open {
    /// Error type for scoped file descriptor operations.
    ///
    /// Captures errors from any phase of a scoped operation:
    /// - Opening the file
    /// - Running the closure
    /// - Closing the file
    public enum Error<ClosureError: Swift.Error>: Swift.Error, Sendable {
        /// Failed to open the file.
        case open(Kernel.File.Open.Error)
        /// The closure threw an error.
        case operation(ClosureError)
        /// Failed to close the file after successful operation.
        case close(Kernel.Close.Error)
    }
}

// MARK: - Private Implementation

extension File.Descriptor.Open {
    /// Opens a descriptor, runs a closure, and ensures cleanup.
    ///
    /// - Close error policy:
    ///   - Body succeeded → propagate close error
    ///   - Body threw → deinit handles cleanup, prefer original error
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
            // Descriptor deinit will close it
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

    /// Async variant of scoped open.
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
            // Descriptor deinit will close it
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

// MARK: - callAsFunction (Read-only default)

extension File.Descriptor.Open {
    /// Opens the file for reading and runs the closure.
    ///
    /// This is the default access mode when calling an `Open` instance directly.
    /// The file descriptor is automatically closed when the closure completes.
    ///
    /// - Parameter body: A closure that receives the file descriptor.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try read(body)
    }

    /// Async variant of callAsFunction.
    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await read(body)
    }
}

// MARK: - Explicit Read

extension File.Descriptor.Open {
    /// Opens the file for reading and runs the closure.
    ///
    /// Same as `callAsFunction` - explicit method for clarity.
    ///
    /// - Parameter body: A closure that receives the file descriptor.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.read, body)
    }

    /// Async variant of read.
    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.read, body)
    }
}

// MARK: - Write

extension File.Descriptor.Open {
    /// Opens the file for writing and runs the closure.
    ///
    /// - Parameter body: A closure that receives the file descriptor.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.write, body)
    }

    /// Async variant of write.
    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.write, body)
    }
}

// MARK: - Appending

extension File.Descriptor.Open {
    /// Opens the file for appending and runs the closure.
    ///
    /// - Parameter body: A closure that receives the file descriptor.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var opts = options
        opts.insert(.append)
        return try File.Descriptor.Open(path: path, options: opts).scoped(mode: Kernel.File.Open.Mode.write, body)
    }

    /// Async variant of appending.
    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        var opts = options
        opts.insert(.append)
        return try await File.Descriptor.Open(path: path, options: opts).scoped(mode: Kernel.File.Open.Mode.write, body)
    }
}

// MARK: - Read-Write

extension File.Descriptor.Open {
    /// Opens the file for reading and writing and runs the closure.
    ///
    /// - Parameter body: A closure that receives the file descriptor.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: .readWrite, body)
    }

    /// Async variant of readWrite.
    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Descriptor) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: .readWrite, body)
    }
}

// MARK: - Factory

extension File.Descriptor {
    /// Returns an `Open` instance for the given path.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// // Read (default)
    /// try File.Descriptor.open(path) { descriptor in ... }
    ///
    /// // Write
    /// try File.Descriptor.open(path).write { descriptor in ... }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public static func open(_ path: borrowing File.Path, options: Kernel.File.Open.Options = []) -> Open {
        Open(path: copy path, options: options)
    }
}
