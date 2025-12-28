//
//  File.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Delete Namespace

extension File {
    /// Namespace for file delete operations.
    ///
    /// Access via the `delete` property on a `File` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// // Common case - callable
    /// try file.delete()
    ///
    /// // Variant - no error if missing
    /// try file.delete.ifExists()
    /// ```
    public struct Delete: Sendable {
        /// The path to delete.
        public let path: File.Path

        /// Creates a Delete instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - callAsFunction (Primary Action)

        /// Deletes the file.
        ///
        /// This is the primary action, accessible via `file.delete()`.
        ///
        /// - Parameter options: Delete options.
        /// - Throws: `File.System.Delete.Error` on failure.
        @inlinable
        public func callAsFunction(
            options: File.System.Delete.Options = .init()
        ) throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path, options: options)
        }

        /// Deletes the file.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>` on failure.
        @inlinable
        public func callAsFunction(
            options: File.System.Delete.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
            try await File.System.Delete.delete(at: path, options: options)
        }

        // MARK: - Variants

        /// Deletes the file if it exists, no error if missing.
        ///
        /// - Parameter options: Delete options.
        /// - Throws: `File.System.Delete.Error` on failure (other than not found).
        @inlinable
        public func ifExists(
            options: File.System.Delete.Options = .init()
        ) throws(File.System.Delete.Error) {
            do {
                try File.System.Delete.delete(at: path, options: options)
            } catch .pathNotFound {
                // Ignore - file doesn't exist
            }
        }

        /// Deletes the file if it exists, no error if missing.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>` on failure (other than not found).
        @inlinable
        public func ifExists(
            options: File.System.Delete.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
            do {
                try await File.System.Delete.delete(at: path, options: options)
            } catch .failure(.operation(.pathNotFound)) {
                // Ignore - file doesn't exist
            }
        }
    }
}

// MARK: - Instance Property

extension File {
    /// Access to delete operations.
    ///
    /// This property returns a callable namespace. Use it directly for the common case,
    /// or access variants via dot syntax:
    /// ```swift
    /// try file.delete()           // common case
    /// try file.delete.ifExists()  // no error if missing
    /// ```
    public var delete: Delete {
        Delete(path)
    }
}
