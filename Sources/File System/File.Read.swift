//
//  File.Read.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
import Kernel
public import Thread_Pool

// MARK: - Read Namespace

extension File {
    /// Namespace for file read operations.
    ///
    /// Access via the `read` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// // Read entire file
    /// let bytes = try file.read.full()
    /// let text = try file.read.full(as: String.self)
    ///
    /// // Stream bytes
    /// for try await chunk in file.read.bytes() { ... }
    /// ```
    public struct Read: Sendable {
        /// The path to read from.
        public let path: File.Path

        /// Creates a Read instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Read {
    // MARK: - Full Read (Sync, Zero-Copy)

    /// Reads the file and passes contents to a closure as a borrowed span.
    ///
    /// This is the canonical read API. The closure receives a `Swift.Span<Byte>`
    /// that borrows from an internal buffer. Copy inside the closure if needed.
    ///
    /// ```swift
    /// // Process without allocation
    /// let checksum = try file.read.full { span in
    ///     computeChecksum(span)
    /// }
    ///
    /// // Copy when needed
    /// let bytes: [UInt8] = try file.read.full { span in
    ///     Array(span)
    /// }
    ///
    /// // Decode as string
    /// let text: String = try file.read.full { span in
    ///     String(decoding: span, as: UTF8.self)
    /// }
    /// ```
    ///
    /// - Parameter body: A closure that receives the file contents as a borrowed span.
    /// - Returns: The value returned by the closure.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    @inlinable
    public func full<R>(
        _ body: (Swift.Span<Byte>) -> R
    ) throws(File.System.Read.Full.Error) -> R {
        try File.System.Read.Full.read(from: path, body: body)
    }

    /// Reads the file and passes contents to a throwing closure as a borrowed span.
    ///
    /// - Parameter body: A throwing closure that receives the file contents.
    /// - Returns: The value returned by the closure.
    /// - Throws: `Either<Read.Full.Error, E>` — `.left` for read failures,
    ///   `.right` if the closure throws.
    @inlinable
    public func full<R, E: Swift.Error>(
        _ body: (Swift.Span<Byte>) throws(E) -> R
    ) throws(Either<File.System.Read.Full.Error, E>) -> R {
        try File.System.Read.Full.read(from: path, body: body)
    }

    // MARK: - Full Read (Async)

    /// Reads the file and passes contents to a closure as a borrowed span.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// The body closure executes on the blocking lane's OS thread,
    /// receiving a `Swift.Span<Byte>` that borrows from the internal read buffer.
    ///
    /// - Parameter body: A sendable closure that receives the file contents.
    /// - Returns: The value returned by the closure.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Read.Full.Error>` on failure.
    @inlinable
    public func full<R: Sendable>(
        _ body: @escaping @Sendable (Swift.Span<Byte>) -> R
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Read.Full.Error>) -> R {
        let path = self.path
        return try await Kernel.Thread.Pool.shared.run { () throws(File.System.Read.Full.Error) -> R in
            try File.System.Read.Full.read(from: path, body: body)
        }
    }

    /// Reads the file and passes contents to a throwing closure as a borrowed span.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// The body closure executes on the blocking lane's OS thread.
    ///
    /// - Parameter body: A sendable throwing closure that receives the file contents.
    /// - Returns: The value returned by the closure.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Either<File.System.Read.Full.Error, E>>` on failure.
    @inlinable
    public func full<R: Sendable, E: Swift.Error>(
        _ body: @escaping @Sendable (Swift.Span<Byte>) throws(E) -> R
    ) async throws(Either<Kernel.Thread.Pool.Error, Either<File.System.Read.Full.Error, E>>) -> R {
        let path = self.path
        return try await Kernel.Thread.Pool.shared.run { () throws(Either<File.System.Read.Full.Error, E>) -> R in
            try File.System.Read.Full.read(from: path, body: body)
        }
    }
}

// MARK: - Instance Property

extension File {
    /// Access to read operations.
    ///
    /// Use this property to read file contents:
    /// ```swift
    /// let bytes = try file.read.full()
    /// let text = try file.read.full(as: String.self)
    ///
    /// // Async variants
    /// let bytes = try await file.read.full()
    /// let text = try await file.read.full(as: String.self)
    /// ```
    public var read: Read {
        Read(path)
    }
}
