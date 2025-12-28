//
//  File.Directory.Entries.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

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
    /// // Async streaming
    /// for try await entry in dir.entries.stream() { ... }
    /// ```
    public struct Entries: Sendable {
        /// The directory path.
        public let path: File.Path

        /// Creates an Entries instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

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
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>` on failure.
        @inlinable
        public func callAsFunction() async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>) -> [File.Directory.Entry] {
            try await File.Directory.Contents.list(at: File.Directory(path))
        }

        // MARK: - Streaming

        /// Returns an async sequence of directory entries.
        ///
        /// Use this for memory-efficient iteration over large directories.
        ///
        /// - Parameter fs: The async file system to use (defaults to `.async`).
        /// - Returns: An async sequence of directory entries.
        @inlinable
        public func stream(
            fs: File.System.Async = .async
        ) -> File.Directory.Contents.Async {
            File.Directory.Async(fs: fs).entries(at: File.Directory(path))
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
    /// for try await entry in dir.entries.stream() { ... }
    /// ```
    public var entries: Entries {
        Entries(path)
    }
}
