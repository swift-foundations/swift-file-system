//
//  File.Copy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

public import IO
public import Thread_Pool

// MARK: - Copy Namespace

extension File {
    /// Namespace for file copy operations.
    ///
    /// Access via the `copy` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/source.txt"
    ///
    /// let copy = try file.copy.to("/tmp/dest.txt")
    /// let copy2 = try await file.copy.to(otherFile, options: .init(overwrite: true))
    /// ```
    public struct Copy: Sendable {
        /// The source path to copy from.
        public let path: File.Path

        /// Creates a Copy instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Copy {
    // MARK: - Copy (Sync)

    /// Copies the file to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Returns: A `File` representing the copy at the destination.
    /// - Throws: `File.System.Copy.Error` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File {
        try File.System.Copy.copy(from: path, to: destination, options: options)
        return File(destination)
    }

    /// Copies the file to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination file.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Returns: The destination `File`.
    /// - Throws: `File.System.Copy.Error` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File {
        try File.System.Copy.copy(from: path, to: destination.path, options: options)
        return destination
    }

    // MARK: - Copy (Async)

    /// Copies the file to a destination path.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Returns: A `File` representing the copy at the destination.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>) -> File {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Copy.Error) in
            try File.System.Copy.copy(from: source, to: destination, options: options)
        }
        return File(destination)
    }

    /// Copies the file to a destination.
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    /// - Returns: The destination `File`.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>` on failure.
    @discardableResult
    @inlinable
    public func to(
        _ destination: File,
        options: File.System.Copy.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>) -> File {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Copy.Error) in
            try File.System.Copy.copy(from: source, to: destination.path, options: options)
        }
        return destination
    }
}

// MARK: - Instance Property

extension File {
    /// Access to copy operations.
    ///
    /// Use this property to copy files:
    /// ```swift
    /// let copy = try file.copy.to("/tmp/copy.txt")
    /// let copy2 = try file.copy.to(otherFile, options: .init(overwrite: true))
    /// ```
    public var copy: Copy {
        Copy(path)
    }
}
