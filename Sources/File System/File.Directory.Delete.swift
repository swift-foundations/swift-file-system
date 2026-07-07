//
//  File.Directory.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

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
    }
}

extension File.Directory.Delete {
    // MARK: - callAsFunction (Primary Action)

    /// Deletes the directory.
    ///
    /// This is the primary action, accessible via `dir.delete()`.
    /// Fails if the directory is not empty.
    ///
    /// - Throws: `File.System.Delete.Error` on failure.
    @inlinable
    public func callAsFunction() throws(File.System.Delete.Error) {
        try File.System.Delete.delete(at: path)
    }

    /// Deletes the directory.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>` on failure.
    @inlinable
    public func callAsFunction() async throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Delete.Error) in
            try File.System.Delete.delete(at: path)
        }
    }

    // MARK: - Variants

    /// Deletes the directory and all its contents.
    ///
    /// - Throws: `File.System.Delete.Error` on failure.
    @inlinable
    public func recursive() throws(File.System.Delete.Error) {
        try File.System.Delete.delete(at: path, recursive: true)
    }

    /// Deletes the directory and all its contents.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>` on failure.
    @inlinable
    public func recursive() async throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Delete.Error) in
            try File.System.Delete.delete(at: path, recursive: true)
        }
    }

    /// Deletes the directory if it exists, no error if missing.
    ///
    /// - Throws: `File.System.Delete.Error` on failure (other than not found).
    @inlinable
    public func ifExists() throws(File.System.Delete.Error) {
        do throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path)
        } catch {
            if error.isNotFound {
                return  // Ignore - directory doesn't exist
            }
            throw error
        }
    }

    /// Deletes the directory if it exists, no error if missing.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>` on failure (other than not found).
    @inlinable
    public func ifExists() async throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
        let path = self.path
        do throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
            try await Kernel.Thread.Pool.shared.run { () throws(File.System.Delete.Error) in
                try File.System.Delete.delete(at: path)
            }
        } catch {
            if case .right(let deleteError) = error, deleteError.isNotFound {
                return  // Ignore - directory doesn't exist
            }
            throw error
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
