//
//  File.Directory.Directories.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

// MARK: - Directories Namespace

extension File.Directory {
    /// Namespace for listing subdirectories in a directory.
    ///
    /// Access via the `directories` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable
    /// for subdir in try dir.directories() { ... }
    ///
    /// // Async
    /// for subdir in try await dir.directories() { ... }
    /// ```
    public struct Directories: Sendable {
        /// The directory path.
        public let path: File.Path

        /// Creates a Directories instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - callAsFunction (Primary Action)

        /// Returns all subdirectories in the directory.
        ///
        /// This is the primary action, accessible via `dir.directories()`.
        ///
        /// - Returns: An array of directories.
        /// - Throws: `File.Directory.Contents.Error` on failure.
        @inlinable
        public func callAsFunction() throws(File.Directory.Contents.Error) -> [File.Directory] {
            try File.Directory.Contents.list(at: File.Directory(path))
                .filter { $0.type == .directory }
                .compactMap { $0.pathIfValid.map { File.Directory($0) } }
        }

        /// Returns all subdirectories in the directory.
        ///
        /// Async variant - runs blocking I/O on a dedicated thread pool.
        /// - Throws: `Either<Kernel.Thread.Pool.Error, File.Directory.Contents.Error>` on failure.
        @inlinable
        public func callAsFunction() async throws(Either<Kernel.Thread.Pool.Error, File.Directory.Contents.Error>) -> [File.Directory] {
            let path = self.path
            return try await Kernel.Thread.Pool.shared.run { () throws(File.Directory.Contents.Error) in
                try File.Directory.Contents.list(at: File.Directory(path))
                    .filter { $0.type == .directory }
                    .compactMap { $0.pathIfValid.map { File.Directory($0) } }
            }
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to subdirectory listing operations.
    ///
    /// This property returns a callable namespace:
    /// ```swift
    /// for subdir in try dir.directories() { ... }
    /// ```
    public var directories: Directories {
        Directories(path)
    }
}
