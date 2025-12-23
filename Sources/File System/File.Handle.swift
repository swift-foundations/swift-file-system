//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Seek Conveniences

extension File.Handle {
    /// Returns the current position in the file.
    ///
    /// Equivalent to `seek(to: 0, from: .current)`.
    ///
    /// - Returns: The current file position.
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func position() throws(File.Handle.Error) -> Int64 {
        try seek(to: 0, from: .current)
    }

    /// Seeks to the beginning of the file.
    ///
    /// Equivalent to `seek(to: 0, from: .start)`.
    ///
    /// ## Example
    /// ```swift
    /// try handle.rewind()
    /// let data = try handle.read(count: 100)  // Read from start
    /// ```
    ///
    /// - Returns: The new position (always 0).
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public mutating func rewind() throws(File.Handle.Error) -> Int64 {
        try seek(to: 0, from: .start)
    }

    /// Seeks to the end of the file.
    ///
    /// Useful for determining file size or appending data.
    ///
    /// ## Example
    /// ```swift
    /// let size = try handle.seekToEnd()  // Returns file size
    /// ```
    ///
    /// - Returns: The new position (file size).
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public mutating func seekToEnd() throws(File.Handle.Error) -> Int64 {
        try seek(to: 0, from: .end)
    }
}

// MARK: - withOpen

extension File.Handle {
    /// Opens a file, runs a closure, and ensures the handle is closed.
    ///
    /// This convenience method handles resource cleanup automatically,
    /// ensuring the file handle is closed when the closure completes,
    /// whether normally or by throwing an error.
    ///
    /// ## Example
    /// ```swift
    /// let content = try File.Handle.withOpen(path, mode: .read) { handle in
    ///     try handle.read(count: 1024)
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// This method uses `File.Error` to distinguish between handle errors
    /// (from opening/closing) and operation errors (from the closure):
    /// ```swift
    /// do {
    ///     try File.Handle.withOpen(path, mode: .read) { handle in
    ///         try handle.read(count: 1024)
    ///     }
    /// } catch .handle(let handleError) {
    ///     // File open/close failed
    /// } catch .operation(let description) {
    ///     // Closure threw an error
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: A closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Error.handle` on open failure, or `File.Error.operation` for closure errors.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) throws -> Result
    ) throws(File.Error) -> Result {
        var handle: File.Handle
        do {
            handle = try open(path, mode: mode, options: options)
        } catch {
            throw .handle(error)
        }

        do {
            let result = try body(&handle)
            try? handle.close()  // Best-effort close after success
            return result
        } catch let error as File.Handle.Error {
            try? handle.close()
            throw .handle(error)
        } catch {
            try? handle.close()
            throw .operation(description: String(describing: error))
        }
    }

    /// Opens a file, runs an async closure, and ensures the handle is closed.
    ///
    /// This is the async variant of `withOpen` for use in async contexts.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: An async closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Error.handle` on open failure, or `File.Error.operation` for closure errors.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) async throws -> Result
    ) async throws(File.Error) -> Result {
        var handle: File.Handle
        do {
            handle = try open(path, mode: mode, options: options)
        } catch {
            throw .handle(error)
        }

        do {
            let result = try await body(&handle)
            try? handle.close()  // Best-effort close after success
            return result
        } catch let error as File.Handle.Error {
            try? handle.close()
            throw .handle(error)
        } catch {
            try? handle.close()
            throw .operation(description: String(describing: error))
        }
    }
}

// MARK: - Async Handle Convenience Methods

extension File.Handle.Async {
    /// Get the current position.
    ///
    /// - Returns: The current file position.
    public func position() async throws(File.IO.Error<File.Handle.Error>) -> Int64 {
        try await seek(to: 0, from: .current)
    }

    /// Seek to the beginning.
    ///
    /// - Returns: The new position (always 0).
    @discardableResult
    public func rewind() async throws(File.IO.Error<File.Handle.Error>) -> Int64 {
        try await seek(to: 0, from: .start)
    }

    /// Seek to the end.
    ///
    /// - Returns: The new position (file size).
    @discardableResult
    public func seekToEnd() async throws(File.IO.Error<File.Handle.Error>) -> Int64 {
        try await seek(to: 0, from: .end)
    }
}
