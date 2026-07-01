//
//  File.Write.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
import Kernel
public import Thread_Pool

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
    ///   - bytes: The bytes to write (borrowed, zero-copy).
    ///   - options: Atomic write options (strategy, durability, preserve settings).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    @inlinable
    public func atomic(
        _ bytes: borrowing Swift.Span<Byte>,
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
        _ string: Swift.String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        let utf8 = [Byte](string.utf8)
        try atomic(utf8.span, options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// - Parameters:
    ///   - bytes: A sequence of bytes to write.
    ///   - options: Atomic write options.
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    @inlinable
    public func atomic<S: Swift.Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) where S.Element == Byte {
        let array = Array(bytes)
        try atomic(array.span, options: options)
    }

    // MARK: - Atomic Write (Async)

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>` on failure.
    @inlinable
    public func atomic(
        _ string: Swift.String,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Atomic.Error) in
            let utf8 = [Byte](string.utf8)
            try File.System.Write.Atomic.write(utf8.span, to: path, options: options)
        }
    }

    /// Writes bytes from a sendable sequence to the file atomically.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>` on failure.
    @inlinable
    public func atomic<S: Swift.Sequence & Sendable>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>)
    where S.Element == Byte {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Atomic.Error) in
            let array = Array(bytes)
            try File.System.Write.Atomic.write(array.span, to: path, options: options)
        }
    }

    // MARK: - Append (Sync)

    /// Appends bytes to the file.
    ///
    /// - Parameter bytes: The bytes to append (borrowed, zero-copy).
    /// - Throws: `File.System.Write.Append.Error` on failure.
    @inlinable
    public func append(_ bytes: borrowing Swift.Span<Byte>) throws(File.System.Write.Append.Error) {
        try File.System.Write.Append.append(bytes, to: path)
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// - Parameter string: The string to append.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    @inlinable
    public func append(_ string: Swift.String) throws(File.System.Write.Append.Error) {
        let utf8 = [Byte](string.utf8)
        try append(utf8.span)
    }

    // MARK: - Append (Async)

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Write.Append.Error>` on failure.
    @inlinable
    public func append(
        _ string: Swift.String
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Append.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Append.Error) in
            let utf8 = [Byte](string.utf8)
            try File.System.Write.Append.append(utf8.span, to: path)
        }
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
    public func streaming<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) throws(File.System.Write.Streaming.Error) where Chunks.Element == [Byte] {
        try File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    // MARK: - Streaming Write (Async)

    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// Async variant for sync sequences - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Write.Streaming.Error>` on failure.
    @inlinable
    public func streaming<Chunks: Swift.Sequence & Sendable>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Streaming.Error>)
    where Chunks.Element == [Byte] {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Streaming.Error) in
            try File.System.Write.Streaming.write(chunks, to: path, options: options)
        }
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
