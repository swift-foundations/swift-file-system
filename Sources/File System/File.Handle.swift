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

// MARK: - Async Handle Convenience Methods

extension File.Handle.Async {
    /// Get the current position.
    ///
    /// - Returns: The current file position.
    public func position() async throws(IO.Lifecycle.Error<IO.Error<File.Handle.Error>>) -> Int64 {
        try await seek(to: 0, from: .current)
    }

    /// Seek to the beginning.
    ///
    /// - Returns: The new position (always 0).
    @discardableResult
    public func rewind() async throws(IO.Lifecycle.Error<IO.Error<File.Handle.Error>>) -> Int64 {
        try await seek(to: 0, from: .start)
    }

    /// Seek to the end.
    ///
    /// - Returns: The new position (file size).
    @discardableResult
    public func seekToEnd() async throws(IO.Lifecycle.Error<IO.Error<File.Handle.Error>>) -> Int64 {
        try await seek(to: 0, from: .end)
    }
}
