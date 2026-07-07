//
//  File.Directory.Move.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

// MARK: - Move Namespace

extension File.Directory {
    /// Namespace for directory move operations.
    ///
    /// Access via the `move` property on a `File.Directory` instance:
    /// ```swift
    /// let dir: File.Directory = "/tmp/source"
    ///
    /// let moved = try dir.move.to("/tmp/dest")
    /// let renamed = try dir.move.rename(to: "newname")
    /// ```
    public struct Move: Sendable {
        /// The source path to move from.
        public let path: File.Path

        /// Creates a Move instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory.Move {
    // MARK: - Move (Sync)

    /// Moves the directory to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Move options (overwrite).
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    /// Moves the directory to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination directory.
    ///   - options: Move options (overwrite).
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        try File.System.Move.move(from: path, to: destination.path, options: options)
        return destination
    }

    /// Renames the directory within the same parent directory.
    ///
    /// - Parameters:
    ///   - newName: The new directory name.
    ///   - options: Move options (overwrite).
    /// - Returns: The renamed directory.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    @inlinable
    public func rename(
        to newName: File.Path.Component,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        guard let parent = path.parent else {
            // Path has no parent (e.g., root path) - cannot rename
            throw .rename(.invalidArgument)
        }
        let destination = parent / newName
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    // MARK: - Move (Async)

    /// Moves the directory to a destination path.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Move.Error>` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination, options: options)
        }
        return File.Directory(destination)
    }

    /// Moves the directory to a destination.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Move.Error>` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination.path, options: options)
        }
        return destination
    }

    /// Renames the directory within the same parent directory.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Move.Error>` on failure.
    @discardableResult
    @inlinable
    public func rename(
        to newName: File.Path.Component,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        guard let parent = path.parent else {
            // Path has no parent (e.g., root path) - cannot rename
            throw .right(.rename(.invalidArgument))
        }
        let destination = parent / newName
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination, options: options)
        }
        return File.Directory(destination)
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to move operations.
    ///
    /// Use this property to move or rename directories:
    /// ```swift
    /// let moved = try dir.move.to("/tmp/dest")
    /// let renamed = try dir.move.rename(to: "newname")
    /// ```
    public var move: Move {
        Move(path)
    }
}
