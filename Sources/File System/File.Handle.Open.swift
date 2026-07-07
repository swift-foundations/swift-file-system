//
//  File.Handle.Open.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Kernel

// MARK: - Open Namespace

extension File.Handle {
    /// Namespace for scoped file open operations.
    ///
    /// This provides an ergonomic API for opening files with automatic cleanup.
    /// Use `File.Handle.open(path)` to get an `Open` instance, then call it
    /// directly for read access, or use `.write`, `.appending`, or `.readWrite`
    /// for other access modes.
    ///
    /// ## Example
    /// ```swift
    /// // Read-only (default)
    /// let data = try File.Handle.open(path) { handle in
    ///     try handle.read(count: 100)
    /// }
    ///
    /// // Write access
    /// try File.Handle.open(path).write { handle in
    ///     try handle.write(bytes)
    /// }
    ///
    /// // Append access
    /// try File.Handle.open(path).appending { handle in
    ///     try handle.write(moreBytes)
    /// }
    ///
    /// // Read-write access
    /// try File.Handle.open(path).readWrite { handle in
    ///     try handle.seek(to: 0)
    ///     try handle.write(bytes)
    /// }
    /// ```
    public struct Open: Swift.Sendable {
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

extension File.Handle.Open {
    /// Error type for scoped file operations.
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

extension File.Handle.Open {
    /// Opens a file, runs a closure, and ensures the handle is closed.
    ///
    /// - Close error policy:
    ///   - Body succeeded → propagate close error
    ///   - Body threw → best-effort cleanup, prefer original error
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
                try handle.close()  // Best-effort cleanup
            } catch {
                // Best-effort cleanup; ignore failures.
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

    /// Async variant of scoped open.
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
                try handle.close()  // Best-effort cleanup
            } catch {
                // Best-effort cleanup; ignore failures.
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

// MARK: - callAsFunction (Read-only default)

extension File.Handle.Open {
    /// Opens the file for reading and runs the closure.
    ///
    /// This is the default access mode when calling an `Open` instance directly.
    /// The file handle is automatically closed when the closure completes.
    ///
    /// - Parameter body: A closure that receives the file handle.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try read(body)
    }

    /// Async variant of callAsFunction.
    @inlinable
    public func callAsFunction<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await read(body)
    }
}

// MARK: - Explicit Read

extension File.Handle.Open {
    /// Opens the file for reading and runs the closure.
    ///
    /// Same as `callAsFunction` - explicit method for clarity.
    ///
    /// - Parameter body: A closure that receives the file handle.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.read, body)
    }

    /// Async variant of read.
    @inlinable
    public func read<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.read, body)
    }
}

// MARK: - Write

extension File.Handle.Open {
    /// Opens the file for writing and runs the closure.
    ///
    /// - Parameter body: A closure that receives the file handle.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: Kernel.File.Open.Mode.write, body)
    }

    /// Async variant of write.
    @inlinable
    public func write<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: Kernel.File.Open.Mode.write, body)
    }
}

// MARK: - Appending

extension File.Handle.Open {
    /// Opens the file for appending and runs the closure.
    ///
    /// Append mode uses write access with the `.append` option, ensuring
    /// all writes atomically position to EOF before writing.
    ///
    /// - Parameter body: A closure that receives the file handle.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func appending<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        var appendOptions = options
        appendOptions.insert(.append)
        let appendOpen = File.Handle.Open(path: path, options: appendOptions)
        return try appendOpen.scoped(mode: .write, body)
    }

    /// Async variant of appending.
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

// MARK: - Read-Write

extension File.Handle.Open {
    /// Opens the file for reading and writing and runs the closure.
    ///
    /// - Parameter body: A closure that receives the file handle.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Open.Error` on open/close failure, or wrapped closure error.
    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) throws(E) -> Result
    ) throws(Error<E>) -> Result {
        try scoped(mode: .readWrite, body)
    }

    /// Async variant of readWrite.
    @inlinable
    public func readWrite<Result, E: Swift.Error>(
        _ body: (inout File.Handle) async throws(E) -> Result
    ) async throws(Error<E>) -> Result {
        try await scoped(mode: .readWrite, body)
    }
}

// MARK: - Factory

extension File.Handle {
    /// Returns an `Open` instance for the given path.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// // Read (default)
    /// try File.Handle.open(path) { handle in ... }
    ///
    /// // Write
    /// try File.Handle.open(path).write { handle in ... }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        options: Kernel.File.Open.Options = []
    ) -> Open {
        Open(path: copy path, options: options)
    }
}
