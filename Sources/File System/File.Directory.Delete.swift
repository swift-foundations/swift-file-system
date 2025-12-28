//
//  File.Directory.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Delete Namespace

extension File.Directory {
    /// Namespace for directory delete operations.
    ///
    /// Access via the `delete` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable (non-recursive, fails if not empty)
    /// try dir.delete()
    ///
    /// // Variants
    /// try dir.delete.recursive()   // removes contents too
    /// try dir.delete.ifExists()    // no error if missing
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

        /// Deletes the directory.
        ///
        /// This is the primary action, accessible via `dir.delete()`.
        /// Fails if the directory is not empty.
        ///
        /// - Throws: `File.System.Delete.Error` on failure.
        @inlinable
        public func callAsFunction() throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path, options: .init(recursive: false))
        }

        /// Deletes the directory.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>` on failure.
        @inlinable
        public func callAsFunction() async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
            try await File.System.Delete.delete(at: path, options: .init(recursive: false))
        }

        // MARK: - Variants

        /// Deletes the directory and all its contents.
        ///
        /// - Throws: `File.System.Delete.Error` on failure.
        @inlinable
        public func recursive() throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path, options: .init(recursive: true))
        }

        /// Deletes the directory and all its contents.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>` on failure.
        @inlinable
        public func recursive() async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
            try await File.System.Delete.delete(at: path, options: .init(recursive: true))
        }

        /// Deletes the directory if it exists, no error if missing.
        ///
        /// - Throws: `File.System.Delete.Error` on failure (other than not found).
        @inlinable
        public func ifExists() throws(File.System.Delete.Error) {
            do {
                try File.System.Delete.delete(at: path, options: .init(recursive: false))
            } catch .pathNotFound {
                // Ignore - directory doesn't exist
            }
        }

        /// Deletes the directory if it exists, no error if missing.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>` on failure (other than not found).
        @inlinable
        public func ifExists() async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
            do {
                try await File.System.Delete.delete(at: path, options: .init(recursive: false))
            } catch .failure(.operation(.pathNotFound)) {
                // Ignore - directory doesn't exist
            }
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to delete operations.
    ///
    /// This property returns a callable namespace. Use it directly for the common case,
    /// or access variants via dot syntax:
    /// ```swift
    /// try dir.delete()             // non-recursive (fails if not empty)
    /// try dir.delete.recursive()   // removes contents too
    /// try dir.delete.ifExists()    // no error if missing
    /// ```
    public var delete: Delete {
        Delete(path)
    }
}
