//
//  File.Create.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Create Namespace

extension File {
    /// Namespace for file creation operations.
    ///
    /// Access via the `create` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// // Create empty file or update timestamp
    /// try file.create.touch()
    /// ```
    public struct Create: Sendable {
        /// The path to create at.
        public let path: File.Path

        /// Creates a Create instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - Touch (Sync)

        /// Creates an empty file or updates its timestamp if it exists.
        ///
        /// - Returns: The file for chaining.
        /// - Throws: `File.Handle.Error` on failure.
        @discardableResult
        @inlinable
        public func touch() throws(File.Handle.Error) -> File {
            try File.Handle.open(path, options: [.create]).readWrite { _ in }
            return File(path)
        }

        // MARK: - Touch (Async)

        /// Creates an empty file or updates its timestamp if it exists.
        ///
        /// Async variant.
        /// - Returns: The file for chaining.
        /// - Throws: `File.Handle.Error` on failure.
        @discardableResult
        @inlinable
        public func touch() async throws(File.Handle.Error) -> File {
            try File.Handle.open(path, options: [.create]).readWrite { _ in }
            return File(path)
        }
    }
}

// MARK: - Instance Property

extension File {
    /// Access to create operations.
    ///
    /// Use this property to create files:
    /// ```swift
    /// try file.create.touch()
    /// ```
    public var create: Create {
        Create(path)
    }
}
