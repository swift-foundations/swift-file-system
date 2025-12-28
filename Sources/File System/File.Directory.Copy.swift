//
//  File.Directory.Copy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Copy Namespace

extension File.Directory {
    /// Namespace for directory copy operations.
    ///
    /// Access via the `copy` property on a `File.Directory` instance:
    /// ```swift
    /// let dir: File.Directory = "/tmp/source"
    ///
    /// let copy = try dir.copy.to("/tmp/dest")
    /// let copy2 = try await dir.copy.to(otherDir, options: .init(overwrite: true))
    /// ```
    public struct Copy: Sendable {
        /// The source path to copy from.
        public let path: File.Path

        /// Creates a Copy instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - Copy (Sync)

        /// Copies the directory to a destination path.
        ///
        /// - Parameters:
        ///   - destination: The destination path.
        ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
        /// - Returns: A `File.Directory` representing the copy at the destination.
        /// - Throws: `File.System.Copy.Error` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Path,
            options: File.System.Copy.Options = .init()
        ) throws(File.System.Copy.Error) -> File.Directory {
            try File.System.Copy.copy(from: path, to: destination, options: options)
            return File.Directory(destination)
        }

        /// Copies the directory to a destination.
        ///
        /// - Parameters:
        ///   - destination: The destination directory.
        ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
        /// - Returns: The destination `File.Directory`.
        /// - Throws: `File.System.Copy.Error` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Directory,
            options: File.System.Copy.Options = .init()
        ) throws(File.System.Copy.Error) -> File.Directory {
            try File.System.Copy.copy(from: path, to: destination.path, options: options)
            return destination
        }

        // MARK: - Copy (Async)

        /// Copies the directory to a destination path.
        ///
        /// Async variant.
        /// - Returns: A `File.Directory` representing the copy at the destination.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Path,
            options: File.System.Copy.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>) -> File.Directory {
            try await File.System.Copy.copy(from: path, to: destination, options: options)
            return File.Directory(destination)
        }

        /// Copies the directory to a destination.
        ///
        /// Async variant.
        /// - Returns: The destination `File.Directory`.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Directory,
            options: File.System.Copy.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>) -> File.Directory {
            try await File.System.Copy.copy(from: path, to: destination.path, options: options)
            return destination
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to copy operations.
    ///
    /// Use this property to copy directories:
    /// ```swift
    /// let copy = try dir.copy.to("/tmp/dest")
    /// let copy2 = try dir.copy.to(otherDir, options: .init(overwrite: true))
    /// ```
    public var copy: Copy {
        Copy(path)
    }
}
