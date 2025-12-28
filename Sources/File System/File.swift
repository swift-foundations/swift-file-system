//
//  File.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Read Operations

extension File {
    /// Reads the entire file contents into memory.
    ///
    /// - Returns: The file contents as an array of bytes.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    public func read() throws(File.System.Read.Full.Error) -> [UInt8] {
        try File.System.Read.Full.read(from: path)
    }

    /// Reads the entire file contents into memory.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Read.Full.Error>` on failure.
    public func read() async throws(IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>) -> [UInt8] {
        try await File.System.Read.Full.read(from: path)
    }

    /// Reads the file contents as a UTF-8 string.
    ///
    /// - Parameters:
    ///   - type: The string type to decode as (e.g., `String.self`).
    /// - Returns: The file contents decoded as UTF-8.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    public func read<S: StringProtocol>(as type: S.Type) throws(File.System.Read.Full.Error) -> S {
        let bytes = try File.System.Read.Full.read(from: path)
        return S(decoding: bytes, as: UTF8.self)
    }

    /// Reads the file contents as a UTF-8 string.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Read.Full.Error>` on failure.
    public func read<S: StringProtocol>(
        as type: S.Type
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>) -> S {
        let bytes = try await File.System.Read.Full.read(from: path)
        return S(decoding: bytes, as: UTF8.self)
    }
}

// MARK: - Write Operations

extension File {
    /// Writes bytes to the file atomically.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to write.
    ///   - options: Atomic write options (strategy, durability, preserve settings).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        _ bytes: [UInt8],
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(bytes, to: path, options: options)
    }

    /// Writes bytes to the file atomically.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Write.Atomic.Error>` on failure.
    public func write(
        _ bytes: [UInt8],
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) {
        try await File.System.Write.Atomic.write(bytes, to: path, options: options)
    }

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// - Parameters:
    ///   - string: The string to write.
    ///   - options: Atomic write options (strategy, durability, preserve settings).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        _ string: String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try write(Array(string.utf8), options: options)
    }

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Write.Atomic.Error>` on failure.
    public func write(
        _ string: String,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) {
        try await write(Array(string.utf8), options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// - Parameters:
    ///   - bytes: A sequence of bytes to write.
    ///   - options: Atomic write options (strategy, durability, preserve settings).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write<S: Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) where S.Element == UInt8 {
        try write(Array(bytes), options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Write.Atomic.Error>` on failure.
    public func write<S: Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) where S.Element == UInt8 {
        try await write(Array(bytes), options: options)
    }

    /// Appends bytes to the file.
    ///
    /// - Parameter bytes: The bytes to append.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public func append(_ bytes: [UInt8]) throws(File.System.Write.Append.Error) {
        try File.System.Write.Append.append(bytes.span, to: path)
    }

    /// Appends bytes to the file.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Write.Append.Error>` on failure.
    public func append(_ bytes: [UInt8]) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>) {
        try await File.System.Write.Append.append(bytes, to: path)
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// - Parameter string: The string to append.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public func append(_ string: String) throws(File.System.Write.Append.Error) {
        try append(Array(string.utf8))
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Write.Append.Error>` on failure.
    public func append(_ string: String) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>) {
        try await append(Array(string.utf8))
    }
}

// MARK: - Streaming Write Operations

extension File {
    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// By default uses atomic mode (temp file + rename) for crash safety.
    /// For large files, this is more memory-efficient than `write(_:)`.
    ///
    /// Accepts any `Sequence where Element == [UInt8]`, including lazy sequences.
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: `File.System.Write.Streaming.Error` on failure.
    public func write<Chunks: Sequence>(
        streaming chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) throws(File.System.Write.Streaming.Error) where Chunks.Element == [UInt8] {
        try File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// Async variant. Accepts any `Sequence where Element == [UInt8]`.
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: `IO.Error<File.System.Write.Streaming.Error>` on failure.
    public func write<Chunks: Sequence & Sendable>(
        streaming chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>)
    where Chunks.Element == [UInt8] {
        try await File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    /// Writes chunks from an async sequence to the file.
    ///
    /// True streaming implementation - processes chunks as they arrive.
    ///
    /// - Parameters:
    ///   - chunks: Async sequence of owned byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: On failure (untyped due to async sequence complexity).
    public func write<Chunks: AsyncSequence & Sendable>(
        streaming chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws where Chunks.Element == [UInt8] {
        try await File.System.Write.Streaming.write(chunks, to: path, options: options)
    }
}

// MARK: - Touch

extension File {
    /// Creates an empty file or updates its timestamp if it exists.
    ///
    /// - Returns: Self for chaining.
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public func touch() throws(File.Handle.Error) -> Self {
        // Opening with .create and readWrite mode will create the file if it doesn't exist,
        // or update its access/modification times if it does.
        try File.Handle.open(path, options: [.create]).readWrite { _ in }
        return self
    }

    /// Creates an empty file or updates its timestamp if it exists.
    ///
    /// Async variant.
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public func touch() async throws(File.Handle.Error) -> Self {
        try File.Handle.open(path, options: [.create]).readWrite { _ in }
        return self
    }
}

// MARK: - Stat Operations

extension File {
    /// Returns `true` if the file exists.
    public var exists: Bool {
        File.System.Stat.exists(at: path)
    }

    /// Returns `true` if the path is a regular file.
    public var isFile: Bool {
        File.System.Stat.isFile(at: path)
    }

    /// Returns `true` if the path is a directory.
    public var isDirectory: Bool {
        File.System.Stat.isDirectory(at: path)
    }

    /// Returns `true` if the path is a symbolic link.
    public var isSymlink: Bool {
        File.System.Stat.isSymlink(at: path)
    }
}

// MARK: - Metadata

extension File {
    /// Returns file metadata information.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var info: File.System.Metadata.Info {
        get throws(File.System.Stat.Error) {
            try File.System.Stat.info(at: path)
        }
    }

    /// Returns the file size in bytes.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var size: Int64 {
        get throws(File.System.Stat.Error) {
            try info.size
        }
    }

    /// Returns the file permissions.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var permissions: File.System.Metadata.Permissions {
        get throws(File.System.Stat.Error) {
            try info.permissions
        }
    }

    /// Returns `true` if the file is empty (size is 0).
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var isEmpty: Bool {
        get throws(File.System.Stat.Error) {
            try size == 0
        }
    }
}

// MARK: - File Operations

extension File {
    /// Deletes the file.
    ///
    /// - Parameter options: Delete options (e.g., recursive for directories).
    /// - Throws: `File.System.Delete.Error` on failure.
    public func delete(
        options: File.System.Delete.Options = .init()
    ) throws(File.System.Delete.Error) {
        try File.System.Delete.delete(at: path, options: options)
    }

    /// Deletes the file.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Delete.Error>` on failure.
    public func delete(
        options: File.System.Delete.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
        try await File.System.Delete.delete(at: path, options: options)
    }

    /// Copies the file to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Returns: A `File` representing the copy at the destination.
    /// - Throws: `File.System.Copy.Error` on failure.
    @discardableResult
    public func copy(
        to destination: File.Path,
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
    public func copy(
        to destination: File,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File {
        try File.System.Copy.copy(from: path, to: destination.path, options: options)
        return destination
    }

    /// Copies the file to a destination path.
    ///
    /// Async variant.
    /// - Returns: A `File` representing the copy at the destination.
    /// - Throws: `IO.Error<File.System.Copy.Error>` on failure.
    @discardableResult
    public func copy(
        to destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>) -> File {
        try await File.System.Copy.copy(from: path, to: destination, options: options)
        return File(destination)
    }

    /// Copies the file to a destination.
    ///
    /// Async variant.
    /// - Returns: The destination `File`.
    /// - Throws: `IO.Error<File.System.Copy.Error>` on failure.
    @discardableResult
    public func copy(
        to destination: File,
        options: File.System.Copy.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>) -> File {
        try await File.System.Copy.copy(from: path, to: destination.path, options: options)
        return destination
    }

    /// Moves the file to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Move options (overwrite).
    /// - Returns: The destination `File`.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    public func move(
        to destination: File.Path,
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
    public func move(
        to destination: File,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File {
        try File.System.Move.move(from: path, to: destination.path, options: options)
        return destination
    }

    /// Moves the file to a destination path.
    ///
    /// Async variant.
    /// - Returns: The destination `File`.
    /// - Throws: `IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
    public func move(
        to destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) -> File {
        try await File.System.Move.move(from: path, to: destination, options: options)
        return File(destination)
    }

    /// Moves the file to a destination.
    ///
    /// Async variant.
    /// - Returns: The destination `File`.
    /// - Throws: `IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
    public func move(
        to destination: File,
        options: File.System.Move.Options = .init()
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) -> File {
        try await File.System.Move.move(from: path, to: destination.path, options: options)
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

    /// Renames the file within the same directory.
    ///
    /// Async variant.
    /// - Throws: `IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
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

// MARK: - Path Navigation

extension File {
    /// The parent directory as a file, or `nil` if this is a root path.
    public var parent: File? {
        path.parent.map(File.init)
    }

    /// The file name (last component of the path).
    public var name: String {
        path.lastComponent?.string ?? ""
    }

    /// The file extension, or `nil` if there is none.
    public var `extension`: String? {
        path.extension
    }

    /// The filename without extension.
    public var stem: String? {
        path.stem
    }

    /// Returns a new file with the given component appended.
    ///
    /// - Parameter component: The component to append.
    /// - Returns: A new file with the appended path.
    public func appending(_ component: String) -> File {
        File(path.appending(component))
    }

    /// Appends a component to a file.
    ///
    /// - Parameters:
    ///   - lhs: The base file.
    ///   - rhs: The component to append.
    /// - Returns: A new file with the appended path.
    public static func / (lhs: File, rhs: String) -> File {
        lhs.appending(rhs)
    }
}

// MARK: - CustomStringConvertible

extension File: CustomStringConvertible {
    public var description: String {
        String(path)
    }
}

// MARK: - CustomDebugStringConvertible

extension File: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File(\(String(path).debugDescription))"
    }
}

// MARK: - Link Operations

extension File {
    /// Access to link operations.
    ///
    /// Use this property to create symbolic links, hard links, or read link targets:
    /// ```swift
    /// // Create a symbolic link
    /// try file.link.symbolic(to: targetPath)
    ///
    /// // Create a hard link
    /// try file.link.hard(to: existingPath)
    ///
    /// // Read the target of a symlink
    /// let target = try file.link.target.path
    /// ```
    public var link: Link {
        Link(path: path)
    }

    /// Namespace for link operations on a file.
    public struct Link: Sendable {
        /// The path to operate on.
        public let path: File.Path

        /// Creates a Link instance.
        @usableFromInline
        internal init(path: File.Path) {
            self.path = path
        }

        // MARK: - Symbolic Links

        /// Creates a symbolic link at this path pointing to the target.
        ///
        /// - Parameter target: The path the symlink will point to.
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        public func symbolic(to target: File.Path) throws(File.System.Link.Symbolic.Error) {
            try File.System.Link.Symbolic.create(at: path, pointingTo: target)
        }

        /// Creates a symbolic link at this path pointing to the target.
        ///
        /// - Parameter target: The target file.
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        public func symbolic(to target: File) throws(File.System.Link.Symbolic.Error) {
            try File.System.Link.Symbolic.create(at: path, pointingTo: target.path)
        }

        // MARK: - Hard Links

        /// Creates a hard link at this path to an existing file.
        ///
        /// Hard links share the same inode as the original file.
        ///
        /// - Parameter existing: The path to the existing file.
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        public func hard(to existing: File.Path) throws(File.System.Link.Hard.Error) {
            try File.System.Link.Hard.create(at: path, to: existing)
        }

        /// Creates a hard link at this path to an existing file.
        ///
        /// - Parameter existing: The existing file.
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        public func hard(to existing: File) throws(File.System.Link.Hard.Error) {
            try File.System.Link.Hard.create(at: path, to: existing.path)
        }

        // MARK: - Read Target

        /// Namespace for reading symlink target.
        ///
        /// ## Usage
        /// ```swift
        /// let targetPath = try link.target.path
        /// let targetFile = try link.target.file
        /// ```
        public var target: Target { Target(link: self) }

        /// Target reading namespace.
        public struct Target: Sendable {
            let link: Link

            /// Reads the target of this symbolic link.
            ///
            /// - Returns: The target path that this symlink points to.
            /// - Throws: `File.System.Link.Read.Target.Error` on failure.
            public var path: File.Path {
                get throws(File.System.Link.Read.Target.Error) {
                    try File.System.Link.Read.Target.target(of: link.path)
                }
            }

            /// Reads the target of this symbolic link as a file.
            ///
            /// - Returns: The target file that this symlink points to.
            /// - Throws: `File.System.Link.Read.Target.Error` on failure.
            public var file: File {
                get throws(File.System.Link.Read.Target.Error) {
                    File(try File.System.Link.Read.Target.target(of: link.path))
                }
            }
        }
    }
}
