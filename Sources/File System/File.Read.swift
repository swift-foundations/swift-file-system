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
    /// // Non-throwing closure: `E` is `Never`, so the closure arm of the thrown
    /// // `Either` is uninhabited and `error.value` recovers the read error.
    /// do throws(Either<File.System.Read.Full.Error, Never>) {
    ///     let checksum = try file.read.full { span in
    ///         computeChecksum(span)
    ///     }
    /// } catch {
    ///     let failure: File.System.Read.Full.Error = error.value
    /// }
    ///
    /// // Throwing closure: both arms are inhabited.
    /// do throws(Either<File.System.Read.Full.Error, Decode.Error>) {
    ///     let value = try file.read.full { span in
    ///         try decode(span)
    ///     }
    /// } catch {
    ///     switch error {
    ///     case .left(let readFailure): ...
    ///     case .right(let closureFailure): ...
    ///     }
    /// }
    /// ```
    ///
    /// A non-throwing closure infers `E` as `Never`, so the thrown type collapses
    /// to `Either<File.System.Read.Full.Error, Never>` and the closure arm is
    /// statically uninhabited — recover the read error with `error.value`.
    ///
    /// - Parameter body: A closure that receives the file contents as a borrowed span.
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
    /// A non-throwing closure infers `E` as `Never`, so the inner arm of the
    /// thrown `Either` is statically uninhabited.
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
