//
//  File.Read.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

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

        // MARK: - Full Read (Sync)

        /// Reads the entire file contents into memory.
        ///
        /// - Returns: The file contents as an array of bytes.
        /// - Throws: `File.System.Read.Full.Error` on failure.
        @inlinable
        public func full() throws(File.System.Read.Full.Error) -> [UInt8] {
            try File.System.Read.Full.read(from: path)
        }

        /// Reads the file contents as a UTF-8 string.
        ///
        /// - Parameter type: The string type to decode as (e.g., `String.self`).
        /// - Returns: The file contents decoded as UTF-8.
        /// - Throws: `File.System.Read.Full.Error` on failure.
        @inlinable
        public func full<S: StringProtocol>(as type: S.Type) throws(File.System.Read.Full.Error) -> S {
            let bytes = try File.System.Read.Full.read(from: path)
            return S(decoding: bytes, as: UTF8.self)
        }

        // MARK: - Full Read (Async)

        /// Reads the entire file contents into memory.
        ///
        /// Async variant.
        /// - Returns: The file contents as an array of bytes.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>` on failure.
        @inlinable
        public func full() async throws(IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>) -> [UInt8] {
            try await File.System.Read.Full.read(from: path)
        }

        /// Reads the file contents as a UTF-8 string.
        ///
        /// Async variant.
        /// - Parameter type: The string type to decode as (e.g., `String.self`).
        /// - Returns: The file contents decoded as UTF-8.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>` on failure.
        @inlinable
        public func full<S: StringProtocol>(
            as type: S.Type
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>) -> S {
            let bytes = try await File.System.Read.Full.read(from: path)
            return S(decoding: bytes, as: UTF8.self)
        }

        // MARK: - Streaming Read

        /// Returns an async sequence of byte chunks from the file.
        ///
        /// Use this for memory-efficient reading of large files.
        ///
        /// - Parameters:
        ///   - fs: The async file system to use (defaults to `.async`).
        ///   - options: Read options.
        /// - Returns: An async sequence of byte arrays.
        @inlinable
        public func bytes(
            fs: File.System.Async = .async,
            options: File.System.Read.Async.Options = .init()
        ) -> File.System.Read.Async.Sequence {
            File.System.Read.Async(fs: fs).bytes(from: path, options: options)
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
    /// for try await chunk in file.read.bytes() { ... }
    /// ```
    public var read: Read {
        Read(path)
    }
}
