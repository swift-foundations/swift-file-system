//
//  File.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

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
    }
}

extension File.Delete {
    // MARK: - callAsFunction (Primary Action)

    /// Deletes the file.
    ///
    /// This is the primary action, accessible via `file.delete()`.
    ///
    /// - Throws: `File.System.Delete.Error` on failure.
    @inlinable
    public func callAsFunction() throws(File.System.Delete.Error) {
        try File.System.Delete.delete(at: path)
    }

    /// Deletes the file.
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

    /// Deletes the file if it exists, no error if missing.
    ///
    /// - Throws: `File.System.Delete.Error` on failure (other than not found).
    @inlinable
    public func ifExists() throws(File.System.Delete.Error) {
        do throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path)
        } catch {
            if error.isNotFound {
                return  // Ignore - file doesn't exist
            }
            throw error
        }
    }

    /// Deletes the file if it exists, no error if missing.
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
                return  // Ignore - file doesn't exist
            }
            throw error
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
