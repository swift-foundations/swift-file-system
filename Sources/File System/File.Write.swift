//
//  File.Write.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Write Namespace

extension File {
    /// Namespace for file write operations.
    ///
    /// Access via the `write` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// // Atomic write (safe, uses temp file + rename)
    /// try file.write.atomic(bytes)
    /// try file.write.atomic("Hello, World!")
    ///
    /// // Append to file
    /// try file.write.append(moreBytes)
    ///
    /// // Stream write
    /// try file.write.streaming(chunks)
    /// ```
    public struct Write: Sendable {
        /// The path to write to.
        public let path: File.Path

        /// Creates a Write instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Write {

    // MARK: - Atomic Write (Sync)

    /// Writes bytes to the file atomically.
    ///
    /// Uses a temp file + rename strategy for crash safety.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to write.
    ///   - options: Atomic write options (strategy, durability, preserve settings).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    @inlinable
    public func atomic(
        _ bytes: [UInt8],
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(bytes, to: path, options: options)
    }

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// - Parameters:
    ///   - string: The string to write.
    ///   - options: Atomic write options.
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    @inlinable
    public func atomic(
        _ string: String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try atomic(Array(string.utf8), options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// - Parameters:
    ///   - bytes: A sequence of bytes to write.
    ///   - options: Atomic write options.
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    @inlinable
    public func atomic<S: Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) where S.Element == UInt8 {
        try atomic(Array(bytes), options: options)
    }

    // MARK: - Atomic Write (Async)

    /// Writes bytes to the file atomically.
    ///
    /// Async variant.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>` on failure.
    @inlinable
    public func atomic(
        _ bytes: [UInt8],
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) {
        try await File.System.Write.Atomic.write(bytes, to: path, options: options)
    }

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// Async variant.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>` on failure.
    @inlinable
    public func atomic(
        _ string: String,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) {
        try await atomic(Array(string.utf8), options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// Async variant.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>` on failure.
    @inlinable
    public func atomic<S: Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) where S.Element == UInt8 {
        try await atomic(Array(bytes), options: options)
    }

    // MARK: - Append (Sync)

    /// Appends bytes to the file.
    ///
    /// - Parameter bytes: The bytes to append.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    @inlinable
    public func append(_ bytes: [UInt8]) throws(File.System.Write.Append.Error) {
        try File.System.Write.Append.append(bytes.span, to: path)
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// - Parameter string: The string to append.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    @inlinable
    public func append(_ string: String) throws(File.System.Write.Append.Error) {
        try append(Array(string.utf8))
    }

    // MARK: - Append (Async)

    /// Appends bytes to the file.
    ///
    /// Async variant.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>` on failure.
    @inlinable
    public func append(
        _ bytes: [UInt8]
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>) {
        try await File.System.Write.Append.append(bytes, to: path)
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// Async variant.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>` on failure.
    @inlinable
    public func append(
        _ string: String
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>) {
        try await append(Array(string.utf8))
    }

    // MARK: - Streaming Write (Sync)

    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// By default uses atomic mode (temp file + rename) for crash safety.
    ///
    /// - Parameters:
    ///   - chunks: Sequence of byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: `File.System.Write.Streaming.Error` on failure.
    @inlinable
    public func streaming<Chunks: Sequence>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) throws(File.System.Write.Streaming.Error) where Chunks.Element == [UInt8] {
        try File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    // MARK: - Streaming Write (Async)

    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// Async variant for sync sequences.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>` on failure.
    @inlinable
    public func streaming<Chunks: Sequence & Sendable>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>)
    where Chunks.Element == [UInt8] {
        try await File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    /// Writes chunks from an async sequence to the file.
    ///
    /// True streaming implementation - processes chunks as they arrive.
    ///
    /// - Parameters:
    ///   - chunks: Async sequence of byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: On failure (untyped due to async sequence complexity).
    @inlinable
    public func streaming<Chunks: AsyncSequence & Sendable>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws where Chunks.Element == [UInt8] {
        try await File.System.Write.Streaming.write(chunks, to: path, options: options)
    }
}

// MARK: - Instance Property

extension File {
    /// Access to write operations.
    ///
    /// Use this property to write file contents:
    /// ```swift
    /// try file.write.atomic(bytes)
    /// try file.write.atomic("Hello!")
    /// try file.write.append(moreBytes)
    /// try file.write.streaming(chunks)
    /// ```
    public var write: File.Write {
        File.Write(path)
    }
}
