//
//  File.Move.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Move Namespace

extension File {
    /// Namespace for file move operations.
    ///
    /// Access via the `move` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/source.txt"
    ///
    /// let moved = try file.move.to("/tmp/dest.txt")
    /// let renamed = try file.move.rename(to: "newname.txt")
    /// ```
    public struct Move: Sendable {
        /// The source path to move from.
        public let path: File.Path

        /// Creates a Move instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - Move (Sync)

        /// Moves the file to a destination path.
        ///
        /// - Parameters:
        ///   - destination: The destination path.
        ///   - options: Move options (overwrite).
        /// - Returns: The destination `File`.
        /// - Throws: `File.System.Move.Error` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Path,
            options: File.System.Move.Options = .init()
        ) throws(File.System.Move.Error) -> File {
            try File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
        }

        /// Moves the file to a destination.
        ///
        /// - Parameters:
        ///   - destination: The destination file.
        ///   - options: Move options (overwrite).
        /// - Returns: The destination `File`.
        /// - Throws: `File.System.Move.Error` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File,
            options: File.System.Move.Options = .init()
        ) throws(File.System.Move.Error) -> File {
            try File.System.Move.move(from: path, to: destination.path, options: options)
            return destination
        }

        /// Renames the file within the same directory.
        ///
        /// - Parameters:
        ///   - newName: The new file name.
        ///   - options: Move options (overwrite).
        /// - Returns: The renamed file.
        /// - Throws: `File.System.Move.Error` on failure.
        @discardableResult
        @inlinable
        public func rename(
            to newName: String,
            options: File.System.Move.Options = .init()
        ) throws(File.System.Move.Error) -> File {
            guard let parent = path.parent else {
                throw .sourceNotFound(path)
            }
            let destination = parent.appending(newName)
            try File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
        }

        // MARK: - Move (Async)

        /// Moves the file to a destination path.
        ///
        /// Async variant.
        /// - Returns: The destination `File`.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File.Path,
            options: File.System.Move.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) -> File {
            try await File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
        }

        /// Moves the file to a destination.
        ///
        /// Async variant.
        /// - Returns: The destination `File`.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>` on failure.
        @discardableResult
        @inlinable
        public func to(
            _ destination: File,
            options: File.System.Move.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) -> File {
            try await File.System.Move.move(from: path, to: destination.path, options: options)
            return destination
        }

        /// Renames the file within the same directory.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>` on failure.
        @discardableResult
        @inlinable
        public func rename(
            to newName: String,
            options: File.System.Move.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) -> File {
            guard let parent = path.parent else {
                throw .failure(.operation(.sourceNotFound(path)))
            }
            let destination = parent.appending(newName)
            try await File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
        }
    }
}

// MARK: - Instance Property

extension File {
    /// Access to move operations.
    ///
    /// Use this property to move or rename files:
    /// ```swift
    /// let moved = try file.move.to("/tmp/dest.txt")
    /// let renamed = try file.move.rename(to: "newname.txt")
    /// ```
    public var move: Move {
        Move(path)
    }
}
