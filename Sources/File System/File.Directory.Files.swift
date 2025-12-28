//
//  File.Directory.Files.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Files Namespace

extension File.Directory {
    /// Namespace for listing files in a directory.
    ///
    /// Access via the `files` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable
    /// for file in try dir.files() { ... }
    ///
    /// // Async
    /// for file in try await dir.files() { ... }
    /// ```
    public struct Files: Sendable {
        /// The directory path.
        public let path: File.Path

        /// Creates a Files instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - callAsFunction (Primary Action)

        /// Returns all files in the directory.
        ///
        /// This is the primary action, accessible via `dir.files()`.
        ///
        /// - Returns: An array of files.
        /// - Throws: `File.Directory.Contents.Error` on failure.
        @inlinable
        public func callAsFunction() throws(File.Directory.Contents.Error) -> [File] {
            try File.Directory.Contents.list(at: File.Directory(path))
                .filter { $0.type == .file }
                .compactMap { $0.pathIfValid.map { File($0) } }
        }

        /// Returns all files in the directory.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>` on failure.
        @inlinable
        public func callAsFunction() async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>) -> [File] {
            try await File.Directory.Contents.list(at: File.Directory(path))
                .filter { $0.type == .file }
                .compactMap { $0.pathIfValid.map { File($0) } }
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to file listing operations.
    ///
    /// This property returns a callable namespace:
    /// ```swift
    /// for file in try dir.files() { ... }
    /// ```
    public var files: Files {
        Files(path)
    }
}
