//
//  File.Directory.Entries.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

// MARK: - Entries Namespace

extension File.Directory {
    /// Namespace for directory entry listing operations.
    ///
    /// Access via the `entries` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable
    /// for entry in try dir.entries() { ... }
    ///
    /// // Async
    /// for entry in try await dir.entries() { ... }
    /// ```
    public struct Entries: Sendable {
        /// The directory path.
        public let path: File.Path

        /// Creates an Entries instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory.Entries {
    // MARK: - callAsFunction (Primary Action)

    /// Returns the contents of the directory.
    ///
    /// This is the primary action, accessible via `dir.entries()`.
    ///
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    @inlinable
    public func callAsFunction() throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
        try File.Directory.Contents.list(at: File.Directory(path))
    }

    /// Returns the contents of the directory.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.Directory.Contents.Error>` on failure.
    @inlinable
    public func callAsFunction() async throws(Either<Kernel.Thread.Pool.Error, File.Directory.Contents.Error>) -> [File.Directory.Entry] {
        let path = self.path
        return try await Kernel.Thread.Pool.shared.run { () throws(File.Directory.Contents.Error) in
            try File.Directory.Contents.list(at: File.Directory(path))
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to entry listing operations.
    ///
    /// This property returns a callable namespace:
    /// ```swift
    /// for entry in try dir.entries() { ... }
    /// ```
    public var entries: Entries {
        Entries(path)
    }
}
