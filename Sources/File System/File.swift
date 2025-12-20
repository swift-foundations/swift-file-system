//
//  File+Convenience.swift
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
    public func read() throws -> [UInt8] {
        try File.System.Read.Full.read(from: path)
    }

    /// Reads the entire file contents into memory.
    ///
    /// Async variant.
    public func read() async throws -> [UInt8] {
        try await File.System.Read.Full.read(from: path)
    }

    /// Reads the file contents as a UTF-8 string.
    ///
    /// - Parameters:
    ///   - type: The string type to decode as (e.g., `String.self`).
    /// - Returns: The file contents decoded as UTF-8.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    public func read<S: StringProtocol>(as type: S.Type) throws -> S {
        let bytes = try File.System.Read.Full.read(from: path)
        return S(decoding: bytes, as: UTF8.self)
    }

    /// Reads the file contents as a UTF-8 string.
    ///
    /// Async variant.
    public func read<S: StringProtocol>(as type: S.Type) async throws -> S {
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
    ) throws {
        try bytes.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path, options: options)
        }
    }

    /// Writes bytes to the file atomically.
    ///
    /// Async variant.
    public func write(
        _ bytes: [UInt8],
        options: File.System.Write.Atomic.Options = .init()
    ) async throws {
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
    ) throws {
        try write(Array(string.utf8), options: options)
    }

    /// Writes a string to the file atomically (UTF-8 encoded).
    ///
    /// Async variant.
    public func write(
        _ string: String,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws {
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
    ) throws where S.Element == UInt8 {
        try write(Array(bytes), options: options)
    }

    /// Writes bytes from a sequence to the file atomically.
    ///
    /// Async variant.
    public func write<S: Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws where S.Element == UInt8 {
        try await write(Array(bytes), options: options)
    }

    /// Appends bytes to the file.
    ///
    /// - Parameter bytes: The bytes to append.
    /// - Throws: `File.Handle.Error` on failure.
    public func append(_ bytes: [UInt8]) throws {
        try File.Handle.open(path, options: [.create]).appending { handle in
            try bytes.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try handle.write(span)
            }
        }
    }

    /// Appends bytes to the file.
    ///
    /// Async variant.
    public func append(_ bytes: [UInt8]) async throws {
        try await File.System.Write.Append.append(bytes, to: path)
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// - Parameter string: The string to append.
    /// - Throws: `File.Handle.Error` on failure.
    public func append(_ string: String) throws {
        try append(Array(string.utf8))
    }

    /// Appends a string to the file (UTF-8 encoded).
    ///
    /// Async variant.
    public func append(_ string: String) async throws {
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
    ) throws where Chunks.Element == [UInt8] {
        try File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    /// Writes chunks to the file using streaming (memory-efficient).
    ///
    /// Async variant. Accepts any `Sequence where Element == [UInt8]`.
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: `File.System.Write.Streaming.Error` on failure.
    public func write<Chunks: Sequence & Sendable>(
        streaming chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws where Chunks.Element == [UInt8] {
        try await File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    /// Writes chunks from an async sequence to the file.
    ///
    /// Collects all chunks before writing to maintain atomicity.
    ///
    /// - Parameters:
    ///   - chunks: Async sequence of owned byte arrays to write.
    ///   - options: Streaming write options.
    /// - Throws: `File.System.Write.Streaming.Error` on failure.
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
    public func touch() throws -> Self {
        if exists {
            // Update modification time by opening for write and closing
            try File.Handle.open(path, options: []).readWrite { _ in }
        } else {
            // Create empty file
            try write([UInt8]())
        }
        return self
    }

    /// Creates an empty file or updates its timestamp if it exists.
    ///
    /// Async variant.
    @discardableResult
    public func touch() async throws -> Self {
        if exists {
            try File.Handle.open(path, options: []).readWrite { _ in }
        } else {
            try await write([UInt8]())
        }
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
        get throws {
            try File.System.Stat.info(at: path)
        }
    }

    /// Returns the file size in bytes.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var size: Int64 {
        get throws {
            try info.size
        }
    }

    /// Returns the file permissions.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var permissions: File.System.Metadata.Permissions {
        get throws {
            try info.permissions
        }
    }

    /// Returns `true` if the file is empty (size is 0).
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var isEmpty: Bool {
        get throws {
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
    public func delete(options: File.System.Delete.Options = .init()) throws {
        try File.System.Delete.delete(at: path, options: options)
    }

    /// Deletes the file.
    ///
    /// Async variant.
    public func delete(options: File.System.Delete.Options = .init()) async throws {
        try await File.System.Delete.delete(at: path, options: options)
    }

    /// Copies the file to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Throws: `File.System.Copy.Error` on failure.
    public func copy(
        to destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) throws {
        try File.System.Copy.copy(from: path, to: destination, options: options)
    }

    /// Copies the file to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination file.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Throws: `File.System.Copy.Error` on failure.
    public func copy(
        to destination: File,
        options: File.System.Copy.Options = .init()
    ) throws {
        try File.System.Copy.copy(from: path, to: destination.path, options: options)
    }

    /// Copies the file to a destination path.
    ///
    /// Async variant.
    public func copy(
        to destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws {
        try await File.System.Copy.copy(from: path, to: destination, options: options)
    }

    /// Copies the file to a destination.
    ///
    /// Async variant.
    public func copy(
        to destination: File,
        options: File.System.Copy.Options = .init()
    ) async throws {
        try await File.System.Copy.copy(from: path, to: destination.path, options: options)
    }

    /// Moves the file to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Move options (overwrite).
    /// - Throws: `File.System.Move.Error` on failure.
    public func move(
        to destination: File.Path,
        options: File.System.Move.Options = .init()
    ) throws {
        try File.System.Move.move(from: path, to: destination, options: options)
    }

    /// Moves the file to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination file.
    ///   - options: Move options (overwrite).
    /// - Throws: `File.System.Move.Error` on failure.
    public func move(
        to destination: File,
        options: File.System.Move.Options = .init()
    ) throws {
        try File.System.Move.move(from: path, to: destination.path, options: options)
    }

    /// Moves the file to a destination path.
    ///
    /// Async variant.
    public func move(
        to destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws {
        try await File.System.Move.move(from: path, to: destination, options: options)
    }

    /// Moves the file to a destination.
    ///
    /// Async variant.
    public func move(
        to destination: File,
        options: File.System.Move.Options = .init()
    ) async throws {
        try await File.System.Move.move(from: path, to: destination.path, options: options)
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
    ) throws -> File {
        guard let parent = path.parent else {
            let destination = try File.Path(newName)
            try File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
        }
        let destination = parent.appending(newName)
        try File.System.Move.move(from: path, to: destination, options: options)
        return File(destination)
    }

    /// Renames the file within the same directory.
    ///
    /// Async variant.
    @discardableResult
    public func rename(
        to newName: String,
        options: File.System.Move.Options = .init()
    ) async throws -> File {
        guard let parent = path.parent else {
            let destination = try File.Path(newName)
            try await File.System.Move.move(from: path, to: destination, options: options)
            return File(destination)
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
        path.string
    }
}

// MARK: - CustomDebugStringConvertible

extension File: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File(\(path.string.debugDescription))"
    }
}

// MARK: - Link Operations

extension File {
    /// Creates a symbolic link at this path pointing to the target.
    ///
    /// - Parameter target: The path the symlink will point to.
    /// - Throws: `File.System.Link.Symbolic.Error` on failure.
    public func createSymlink(to target: File.Path) throws {
        try File.System.Link.Symbolic.create(at: path, pointingTo: target)
    }

    /// Creates a symbolic link at this path pointing to the target.
    ///
    /// - Parameter target: The target file.
    /// - Throws: `File.System.Link.Symbolic.Error` on failure.
    public func createSymlink(to target: File) throws {
        try File.System.Link.Symbolic.create(at: path, pointingTo: target.path)
    }

    /// Creates a hard link at this path to an existing file.
    ///
    /// - Parameter existing: The path to the existing file.
    /// - Throws: `File.System.Link.Hard.Error` on failure.
    public func createHardLink(to existing: File.Path) throws {
        try File.System.Link.Hard.create(at: path, to: existing)
    }

    /// Creates a hard link at this path to an existing file.
    ///
    /// - Parameter existing: The existing file.
    /// - Throws: `File.System.Link.Hard.Error` on failure.
    public func createHardLink(to existing: File) throws {
        try File.System.Link.Hard.create(at: path, to: existing.path)
    }

    /// Reads the target of this symbolic link.
    ///
    /// - Returns: The target path that this symlink points to.
    /// - Throws: `File.System.Link.ReadTarget.Error` on failure.
    public func readLinkTarget() throws -> File.Path {
        try File.System.Link.ReadTarget.target(of: path)
    }

    /// Reads the target of this symbolic link as a file.
    ///
    /// - Returns: The target file that this symlink points to.
    /// - Throws: `File.System.Link.ReadTarget.Error` on failure.
    public func readLinkTargetFile() throws -> File {
        File(try File.System.Link.ReadTarget.target(of: path))
    }
}

