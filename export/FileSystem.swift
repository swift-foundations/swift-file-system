// Concatenated export of: File System
// Generated: Sun Dec 21 11:59:20 CET 2025


// ============================================================
// MARK: - Binary.Serializable.swift
// ============================================================

//
//  Binary.Serializable.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Binary

extension Binary.Serializable {
    /// Writes this serializable value atomically to a file.
    ///
    /// Uses the atomic write-sync-rename pattern for crash safety.
    ///
    /// - Parameters:
    ///   - path: Destination file path.
    ///   - options: Write options (strategy, durability, metadata preservation).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        to path: File.Path,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(self, to: path, options: options)
    }

    /// Writes this serializable value atomically to a file.
    ///
    /// Uses the atomic write-sync-rename pattern for crash safety.
    ///
    /// - Parameters:
    ///   - file: Destination file.
    ///   - options: Write options (strategy, durability, metadata preservation).
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        to file: File,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try write(to: file.path, options: options)
    }
}

// ============================================================
// MARK: - File.Descriptor.Open.swift
// ============================================================

//
//  File.Descriptor.Open.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Open Namespace

extension File.Descriptor {
    /// Namespace for scoped file descriptor open operations.
    ///
    /// This provides an ergonomic API for opening files with automatic cleanup.
    /// Use `File.Descriptor.open(path)` to get an `Open` instance, then call it
    /// directly for read access, or use `.write`, `.appending`, or `.readWrite`
    /// for other access modes.
    ///
    /// ## Example
    /// ```swift
    /// // Read-only (default)
    /// let result = try File.Descriptor.open(path) { descriptor in
    ///     // use descriptor
    /// }
    ///
    /// // Write access
    /// try File.Descriptor.open(path).write { descriptor in
    ///     // write to descriptor
    /// }
    /// ```
    public struct Open: Sendable {
        /// The path to open.
        public let path: File.Path
        /// Options for opening.
        public let options: Options

        /// Creates an Open instance.
        @usableFromInline
        internal init(path: File.Path, options: Options) {
            self.path = path
            self.options = options
        }

        // MARK: - callAsFunction (Read-only default)

        /// Opens the file for reading and runs the closure.
        ///
        /// This is the default access mode when calling an `Open` instance directly.
        /// The file descriptor is automatically closed when the closure completes.
        ///
        /// - Parameter body: A closure that receives the file descriptor.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Descriptor.Error` on open failure, or any error from the closure.
        @inlinable
        public func callAsFunction<Result>(
            _ body: (inout File.Descriptor) throws -> Result
        ) throws -> Result {
            try read(body)
        }

        // MARK: - Explicit Read

        /// Opens the file for reading and runs the closure.
        ///
        /// Same as `callAsFunction` - explicit method for clarity.
        ///
        /// - Parameter body: A closure that receives the file descriptor.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Descriptor.Error` on open failure, or any error from the closure.
        @inlinable
        public func read<Result>(
            _ body: (inout File.Descriptor) throws -> Result
        ) throws -> Result {
            try File.Descriptor.withOpen(path, mode: .read, options: options, body: body)
        }

        // MARK: - Write

        /// Opens the file for writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file descriptor.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Descriptor.Error` on open failure, or any error from the closure.
        @inlinable
        public func write<Result>(
            _ body: (inout File.Descriptor) throws -> Result
        ) throws -> Result {
            try File.Descriptor.withOpen(path, mode: .write, options: options, body: body)
        }

        // MARK: - Appending

        /// Opens the file for appending and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file descriptor.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Descriptor.Error` on open failure, or any error from the closure.
        @inlinable
        public func appending<Result>(
            _ body: (inout File.Descriptor) throws -> Result
        ) throws -> Result {
            var opts = options
            opts.insert(.append)
            return try File.Descriptor.withOpen(path, mode: .write, options: opts, body: body)
        }

        // MARK: - Read-Write

        /// Opens the file for reading and writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file descriptor.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Descriptor.Error` on open failure, or any error from the closure.
        @inlinable
        public func readWrite<Result>(
            _ body: (inout File.Descriptor) throws -> Result
        ) throws -> Result {
            try File.Descriptor.withOpen(path, mode: .readWrite, options: options, body: body)
        }
    }

    /// Returns an `Open` instance for the given path.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// // Read (default)
    /// try File.Descriptor.open(path) { descriptor in ... }
    ///
    /// // Write
    /// try File.Descriptor.open(path).write { descriptor in ... }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public static func open(_ path: File.Path, options: Options = []) -> Open {
        Open(path: path, options: options)
    }
}

// ============================================================
// MARK: - File.Descriptor.swift
// ============================================================

//
//  File.Descriptor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Descriptor {
    /// Duplicates this file descriptor.
    ///
    /// Creates a new file descriptor that refers to the same open file.
    /// Both descriptors can be used independently and must be closed separately.
    ///
    /// ## Example
    /// ```swift
    /// let original = try File.Descriptor.open(path, mode: .read)
    /// var duplicate = try original.duplicated()
    /// // Both can be used independently
    /// ```
    ///
    /// - Returns: A new file descriptor referring to the same file.
    /// - Throws: `File.Descriptor.Error.duplicateFailed` on failure.
    @inlinable
    public func duplicated() throws(Error) -> File.Descriptor {
        try File.Descriptor(duplicating: self)
    }
}

extension File.Descriptor {
    /// Opens a file descriptor, runs a closure, and ensures the descriptor is closed.
    ///
    /// This convenience method handles resource cleanup automatically,
    /// ensuring the file descriptor is closed when the closure completes,
    /// whether normally or by throwing an error.
    ///
    /// ## Example
    /// ```swift
    /// let bytesRead = try File.Descriptor.withOpen(path, mode: .read) { descriptor in
    ///     // Use descriptor for low-level I/O
    ///     return try descriptor.read(count: 1024)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: A closure that receives an inout descriptor and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Descriptor) throws -> Result
    ) throws -> Result {
        var descriptor = try open(path, mode: mode, options: options)
        let result: Result
        do {
            result = try body(&descriptor)
        } catch {
            // Descriptor deinit will close it
            _ = consume descriptor
            throw error
        }
        try descriptor.close()
        return result
    }

    /// Opens a file descriptor, runs an async closure, and ensures the descriptor is closed.
    ///
    /// This is the async variant of `withOpen` for use in async contexts.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: An async closure that receives an inout descriptor and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Descriptor.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Descriptor) async throws -> Result
    ) async throws -> Result {
        var descriptor = try open(path, mode: mode, options: options)
        let result: Result
        do {
            result = try await body(&descriptor)
        } catch {
            // Descriptor deinit will close it
            _ = consume descriptor
            throw error
        }
        try descriptor.close()
        return result
    }
}

// MARK: - Error CustomStringConvertible

extension File.Descriptor.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "File already exists: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .tooManyOpenFiles:
            return "Too many open files"
        case .invalidDescriptor:
            return "Invalid file descriptor"
        case .openFailed(let errno, let message):
            return "Open failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .duplicateFailed(let errno, let message):
            return "Duplicate failed: \(message) (errno=\(errno))"
        case .alreadyClosed:
            return "Descriptor already closed"
        }
    }
}

// ============================================================
// MARK: - File.Directory.swift
// ============================================================

//
//  File.Directory.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Directory Operations

extension File.Directory {
    /// Creates the directory.
    ///
    /// - Parameter withIntermediates: Whether to create intermediate directories.
    /// - Throws: `File.System.Create.Directory.Error` on failure.
    public func create(withIntermediates: Bool = false) throws {
        let options = File.System.Create.Directory.Options(createIntermediates: withIntermediates)
        try File.System.Create.Directory.create(at: path, options: options)
    }

    /// Creates the directory.
    ///
    /// Async variant.
    public func create(withIntermediates: Bool = false) async throws {
        let options = File.System.Create.Directory.Options(createIntermediates: withIntermediates)
        try await File.System.Create.Directory.create(at: path, options: options)
    }

    /// Deletes the directory.
    ///
    /// - Parameter recursive: Whether to delete contents recursively.
    /// - Throws: `File.System.Delete.Error` on failure.
    public func delete(recursive: Bool = false) throws {
        let options = File.System.Delete.Options(recursive: recursive)
        try File.System.Delete.delete(at: path, options: options)
    }

    /// Deletes the directory.
    ///
    /// Async variant.
    public func delete(recursive: Bool = false) async throws {
        let options = File.System.Delete.Options(recursive: recursive)
        try await File.System.Delete.delete(at: path, options: options)
    }

    /// Copies the directory to a destination path.
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

    /// Copies the directory to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination directory.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Throws: `File.System.Copy.Error` on failure.
    public func copy(
        to destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) throws {
        try File.System.Copy.copy(from: path, to: destination.path, options: options)
    }

    /// Copies the directory to a destination path.
    ///
    /// Async variant.
    public func copy(
        to destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws {
        try await File.System.Copy.copy(from: path, to: destination, options: options)
    }

    /// Copies the directory to a destination.
    ///
    /// Async variant.
    public func copy(
        to destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) async throws {
        try await File.System.Copy.copy(from: path, to: destination.path, options: options)
    }

    /// Moves the directory to a destination path.
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

    /// Moves the directory to a destination.
    ///
    /// - Parameters:
    ///   - destination: The destination directory.
    ///   - options: Move options (overwrite).
    /// - Throws: `File.System.Move.Error` on failure.
    public func move(
        to destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) throws {
        try File.System.Move.move(from: path, to: destination.path, options: options)
    }

    /// Moves the directory to a destination path.
    ///
    /// Async variant.
    public func move(
        to destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws {
        try await File.System.Move.move(from: path, to: destination, options: options)
    }

    /// Moves the directory to a destination.
    ///
    /// Async variant.
    public func move(
        to destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) async throws {
        try await File.System.Move.move(from: path, to: destination.path, options: options)
    }

    /// Renames the directory within the same parent directory.
    ///
    /// - Parameters:
    ///   - newName: The new directory name.
    ///   - options: Move options (overwrite).
    /// - Returns: The renamed directory.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    public func rename(
        to newName: String,
        options: File.System.Move.Options = .init()
    ) throws -> File.Directory {
        guard let parent = path.parent else {
            let destination = try File.Path(newName)
            try File.System.Move.move(from: path, to: destination, options: options)
            return File.Directory(destination)
        }
        let destination = parent.appending(newName)
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    /// Renames the directory within the same parent directory.
    ///
    /// Async variant.
    @discardableResult
    public func rename(
        to newName: String,
        options: File.System.Move.Options = .init()
    ) async throws -> File.Directory {
        guard let parent = path.parent else {
            let destination = try File.Path(newName)
            try await File.System.Move.move(from: path, to: destination, options: options)
            return File.Directory(destination)
        }
        let destination = parent.appending(newName)
        try await File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }
}

// MARK: - Stat Operations

extension File.Directory {
    /// Returns `true` if the directory exists.
    public var exists: Bool {
        File.System.Stat.exists(at: path)
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

extension File.Directory {
    /// Returns directory metadata information.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var info: File.System.Metadata.Info {
        get throws {
            try File.System.Stat.info(at: path)
        }
    }

    /// Returns the directory permissions.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var permissions: File.System.Metadata.Permissions {
        get throws {
            try info.permissions
        }
    }
}

// MARK: - Contents

extension File.Directory {
    /// Returns the contents of the directory.
    ///
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public func contents() throws -> [File.Directory.Entry] {
        try File.Directory.Contents.list(at: path)
    }

    /// Returns the contents of the directory.
    ///
    /// Async variant. Use `entries()` for true streaming iteration.
    public func contents() async throws -> [File.Directory.Entry] {
        try await File.Directory.Contents.list(at: path)
    }

    /// Returns all files in the directory.
    ///
    /// - Returns: An array of files.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public func files() throws -> [File] {
        try contents()
            .filter { $0.type == .file }
            .compactMap { $0.path.map { File($0) } }
    }

    /// Returns all files in the directory.
    ///
    /// Async variant.
    public func files() async throws -> [File] {
        try await contents()
            .filter { $0.type == .file }
            .compactMap { $0.path.map { File($0) } }
    }

    /// Returns all subdirectories in the directory.
    ///
    /// - Returns: An array of directories.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public func subdirectories() throws -> [File.Directory] {
        try contents()
            .filter { $0.type == .directory }
            .compactMap { $0.path.map { File.Directory($0) } }
    }

    /// Returns all subdirectories in the directory.
    ///
    /// Async variant.
    public func subdirectories() async throws -> [File.Directory] {
        try await contents()
            .filter { $0.type == .directory }
            .compactMap { $0.path.map { File.Directory($0) } }
    }

    /// Returns whether the directory is empty.
    ///
    /// - Returns: `true` if the directory contains no entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public var isEmpty: Bool {
        get throws {
            try contents().isEmpty
        }
    }
}

// MARK: - Walk

extension File.Directory {
    /// Recursively walks the directory tree and returns all entries.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public func walk(
        options: File.Directory.Walk.Options = .init()
    ) throws -> [File.Directory.Entry] {
        try File.Directory.Walk.walk(at: path, options: options)
    }

    /// Recursively walks the directory tree and returns all entries.
    ///
    /// Async variant.
    public func walk(
        options: File.Directory.Walk.Options = .init()
    ) async throws -> [File.Directory.Entry] {
        try await File.Directory.Walk.walk(at: path, options: options)
    }

    /// Recursively walks the directory tree and returns all files.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all files found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public func walkFiles(
        options: File.Directory.Walk.Options = .init()
    ) throws -> [File] {
        try walk(options: options)
            .filter { $0.type == .file }
            .compactMap { $0.path.map { File($0) } }
    }

    /// Recursively walks the directory tree and returns all files.
    ///
    /// Async variant.
    public func walkFiles(
        options: File.Directory.Walk.Options = .init()
    ) async throws -> [File] {
        try await walk(options: options)
            .filter { $0.type == .file }
            .compactMap { $0.path.map { File($0) } }
    }

    /// Recursively walks the directory tree and returns all subdirectories.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all directories found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public func walkDirectories(
        options: File.Directory.Walk.Options = .init()
    ) throws -> [File.Directory] {
        try walk(options: options)
            .filter { $0.type == .directory }
            .compactMap { $0.path.map { File.Directory($0) } }
    }

    /// Recursively walks the directory tree and returns all subdirectories.
    ///
    /// Async variant.
    public func walkDirectories(
        options: File.Directory.Walk.Options = .init()
    ) async throws -> [File.Directory] {
        try await walk(options: options)
            .filter { $0.type == .directory }
            .compactMap { $0.path.map { File.Directory($0) } }
    }
}

// MARK: - Subscript Access

extension File.Directory {
    /// Access a file in this directory.
    ///
    /// - Parameter name: The file name.
    /// - Returns: A file for the named file.
    public subscript(_ name: String) -> File {
        File(path.appending(name))
    }

    /// Access a file in this directory (labeled).
    ///
    /// ## Example
    /// ```swift
    /// let readme = dir[file: "README.md"]
    /// ```
    ///
    /// - Parameter name: The file name.
    /// - Returns: A file for the named file.
    public subscript(file name: String) -> File {
        File(path.appending(name))
    }

    /// Access a subdirectory (labeled).
    ///
    /// ## Example
    /// ```swift
    /// let src = dir[directory: "src"]
    /// let nested = dir[directory: "src"][file: "main.swift"]
    /// ```
    ///
    /// - Parameter name: The subdirectory name.
    /// - Returns: A directory for the named subdirectory.
    public subscript(directory name: String) -> File.Directory {
        File.Directory(path.appending(name))
    }

    /// Access a subdirectory.
    ///
    /// - Parameter name: The subdirectory name.
    /// - Returns: A directory for the named subdirectory.
    public func subdirectory(_ name: String) -> File.Directory {
        File.Directory(path.appending(name))
    }
}

// MARK: - Path Navigation

extension File.Directory {
    /// The parent directory, or `nil` if this is a root path.
    public var parent: File.Directory? {
        path.parent.map(File.Directory.init)
    }

    /// The directory name (last component of the path).
    public var name: String {
        path.lastComponent?.string ?? ""
    }

    /// Returns a new directory with the given component appended.
    ///
    /// - Parameter component: The component to append.
    /// - Returns: A new directory with the appended path.
    public func appending(_ component: String) -> File.Directory {
        File.Directory(path.appending(component))
    }

    /// Appends a component to a directory.
    ///
    /// - Parameters:
    ///   - lhs: The base directory.
    ///   - rhs: The component to append.
    /// - Returns: A new directory with the appended path.
    public static func / (lhs: File.Directory, rhs: String) -> File.Directory {
        lhs.appending(rhs)
    }
}

// MARK: - CustomStringConvertible

extension File.Directory: CustomStringConvertible {
    public var description: String {
        path.string
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Directory: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Directory(\(path.string.debugDescription))"
    }
}


// ============================================================
// MARK: - File.Handle.Open.swift
// ============================================================

//
//  File.Handle.Open.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Open Namespace

extension File.Handle {
    /// Namespace for scoped file open operations.
    ///
    /// This provides an ergonomic API for opening files with automatic cleanup.
    /// Use `File.Handle.open(path)` to get an `Open` instance, then call it
    /// directly for read access, or use `.write`, `.appending`, or `.readWrite`
    /// for other access modes.
    ///
    /// ## Example
    /// ```swift
    /// // Read-only (default)
    /// let data = try File.Handle.open(path) { handle in
    ///     try handle.read(count: 100)
    /// }
    ///
    /// // Write access
    /// try File.Handle.open(path).write { handle in
    ///     try handle.write(bytes)
    /// }
    ///
    /// // Append access
    /// try File.Handle.open(path).appending { handle in
    ///     try handle.write(moreBytes)
    /// }
    ///
    /// // Read-write access
    /// try File.Handle.open(path).readWrite { handle in
    ///     try handle.seek(to: 0)
    ///     try handle.write(bytes)
    /// }
    /// ```
    public struct Open: Sendable {
        /// The path to open.
        public let path: File.Path
        /// Options for opening.
        public let options: Options

        /// Creates an Open instance.
        @usableFromInline
        internal init(path: File.Path, options: Options) {
            self.path = path
            self.options = options
        }

        // MARK: - callAsFunction (Read-only default)

        /// Opens the file for reading and runs the closure.
        ///
        /// This is the default access mode when calling an `Open` instance directly.
        /// The file handle is automatically closed when the closure completes.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func callAsFunction<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try read(body)
        }

        // MARK: - Explicit Read

        /// Opens the file for reading and runs the closure.
        ///
        /// Same as `callAsFunction` - explicit method for clarity.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func read<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .read, options: options, body: body)
        }

        // MARK: - Write

        /// Opens the file for writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func write<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .write, options: options, body: body)
        }

        // MARK: - Appending

        /// Opens the file for appending and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func appending<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .append, options: options, body: body)
        }

        // MARK: - Read-Write

        /// Opens the file for reading and writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func readWrite<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .readWrite, options: options, body: body)
        }
    }

    /// Returns an `Open` instance for the given path.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// // Read (default)
    /// try File.Handle.open(path) { handle in ... }
    ///
    /// // Write
    /// try File.Handle.open(path).write { handle in ... }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public static func open(_ path: File.Path, options: Options = []) -> Open {
        Open(path: path, options: options)
    }
}

// ============================================================
// MARK: - File.Handle.swift
// ============================================================

//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Seek Conveniences

extension File.Handle {
    /// Returns the current position in the file.
    ///
    /// Equivalent to `seek(to: 0, from: .current)`.
    ///
    /// - Returns: The current file position.
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func position() throws(Error) -> Int64 {
        try seek(to: 0, from: .current)
    }

    /// Seeks to the beginning of the file.
    ///
    /// Equivalent to `seek(to: 0, from: .start)`.
    ///
    /// ## Example
    /// ```swift
    /// try handle.rewind()
    /// let data = try handle.read(count: 100)  // Read from start
    /// ```
    ///
    /// - Returns: The new position (always 0).
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public mutating func rewind() throws(Error) -> Int64 {
        try seek(to: 0, from: .start)
    }

    /// Seeks to the end of the file.
    ///
    /// Useful for determining file size or appending data.
    ///
    /// ## Example
    /// ```swift
    /// let size = try handle.seekToEnd()  // Returns file size
    /// ```
    ///
    /// - Returns: The new position (file size).
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public mutating func seekToEnd() throws(Error) -> Int64 {
        try seek(to: 0, from: .end)
    }
}

// MARK: - withOpen

extension File.Handle {
    /// Opens a file, runs a closure, and ensures the handle is closed.
    ///
    /// This convenience method handles resource cleanup automatically,
    /// ensuring the file handle is closed when the closure completes,
    /// whether normally or by throwing an error.
    ///
    /// ## Example
    /// ```swift
    /// let content = try File.Handle.withOpen(path, mode: .read) { handle in
    ///     try handle.read(count: 1024)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: A closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) throws -> Result
    ) throws -> Result {
        var handle = try open(path, mode: mode, options: options)
        do {
            let result = try body(&handle)
            try? handle.close()  // Best-effort close after success
            return result
        } catch {
            try? handle.close()  // Best-effort close after error
            throw error
        }
    }

    /// Opens a file, runs an async closure, and ensures the handle is closed.
    ///
    /// This is the async variant of `withOpen` for use in async contexts.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    ///   - body: An async closure that receives an inout handle and returns a result.
    /// - Returns: The result from the closure.
    /// - Throws: `File.Handle.Error` on open failure, or any error thrown by the closure.
    public static func withOpen<Result>(
        _ path: File.Path,
        mode: Mode,
        options: Options = [],
        body: (inout File.Handle) async throws -> Result
    ) async throws -> Result {
        var handle = try open(path, mode: mode, options: options)
        do {
            let result = try await body(&handle)
            try? handle.close()  // Best-effort close after success
            return result
        } catch {
            try? handle.close()  // Best-effort close after error
            throw error
        }
    }
}

// MARK: - Async Handle Convenience Methods

extension File.Handle.Async {
    /// Get the current position.
    ///
    /// - Returns: The current file position.
    public func position() async throws -> Int64 {
        try await seek(to: 0, from: .current)
    }

    /// Seek to the beginning.
    ///
    /// - Returns: The new position (always 0).
    @discardableResult
    public func rewind() async throws -> Int64 {
        try await seek(to: 0, from: .start)
    }

    /// Seek to the end.
    ///
    /// - Returns: The new position (file size).
    @discardableResult
    public func seekToEnd() async throws -> Int64 {
        try await seek(to: 0, from: .end)
    }
}

// ============================================================
// MARK: - File.Open.swift
// ============================================================

//
//  File.Open.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Open Namespace

extension File {
    /// Namespace for scoped file open operations.
    ///
    /// This provides an ergonomic API for opening files with automatic cleanup.
    /// Use `File.open(path)` or `file.open` to get an `Open` instance, then call it
    /// directly for read access, or use `.write`, `.appending`, or `.readWrite`
    /// for other access modes.
    ///
    /// ## Example
    /// ```swift
    /// // Static API
    /// let data = try File.open(path) { handle in
    ///     try handle.read(count: 100)
    /// }
    ///
    /// // Instance API
    /// let file: File = "/tmp/data.txt"
    /// try file.open.write { handle in
    ///     try handle.write(bytes)
    /// }
    /// ```
    public struct Open: Sendable {
        /// The path to open.
        public let path: File.Path
        /// Options for opening.
        public let options: File.Handle.Options

        /// Creates an Open instance.
        @usableFromInline
        internal init(path: File.Path, options: File.Handle.Options) {
            self.path = path
            self.options = options
        }

        // MARK: - callAsFunction (Read-only default)

        /// Opens the file for reading and runs the closure.
        ///
        /// This is the default access mode when calling an `Open` instance directly.
        /// The file handle is automatically closed when the closure completes.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func callAsFunction<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try read(body)
        }

        // MARK: - Explicit Read

        /// Opens the file for reading and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func read<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .read, options: options, body: body)
        }

        // MARK: - Write

        /// Opens the file for writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func write<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .write, options: options, body: body)
        }

        // MARK: - Appending

        /// Opens the file for appending and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func appending<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .append, options: options, body: body)
        }

        // MARK: - Read-Write

        /// Opens the file for reading and writing and runs the closure.
        ///
        /// - Parameter body: A closure that receives the file handle.
        /// - Returns: The result from the closure.
        /// - Throws: `File.Handle.Error` on open failure, or any error from the closure.
        @inlinable
        public func readWrite<Result>(
            _ body: (inout File.Handle) throws -> Result
        ) throws -> Result {
            try File.Handle.withOpen(path, mode: .readWrite, options: options, body: body)
        }
    }
}

// MARK: - Static API

extension File {
    /// Returns an `Open` instance for the given path.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// // Read (default)
    /// try File.open(path) { handle in ... }
    ///
    /// // Write
    /// try File.open(path).write { handle in ... }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public static func open(_ path: File.Path, options: File.Handle.Options = []) -> Open {
        Open(path: path, options: options)
    }
}

// MARK: - Instance API

extension File {
    /// Returns an `Open` instance for this file.
    ///
    /// Use this to access the ergonomic file opening API:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// // Read (default)
    /// try file.open { handle in ... }
    ///
    /// // Write
    /// try file.open.write { handle in ... }
    ///
    /// // With options
    /// try file.open(options: [.create]).write { handle in ... }
    /// ```
    public var open: Open {
        Open(path: path, options: [])
    }

    /// Returns an `Open` instance for this file with the given options.
    ///
    /// - Parameter options: Options for opening the file.
    /// - Returns: An `Open` instance.
    @inlinable
    public func open(options: File.Handle.Options) -> Open {
        Open(path: path, options: options)
    }
}

// ============================================================
// MARK: - File.Path.Property.swift
// ============================================================

//
//  File.Path.Property.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Path {
    /// A property that can be modified on a path.
    ///
    /// This struct enables extensible path manipulation. Users can define
    /// custom properties beyond the built-in `.extension` and `.lastComponent`.
    ///
    /// ## Example
    /// ```swift
    /// // Built-in properties
    /// path.with(.extension, "txt")
    /// path.removing(.extension)
    ///
    /// // Custom property
    /// extension File.Path.Property {
    ///     static let stem = Property(
    ///         set: { path, value in
    ///             let ext = path.extension
    ///             return path.removing(.extension).parent?.appending(value + (ext.map { ".\($0)" } ?? "")) ?? path
    ///         },
    ///         remove: { $0 }  // Can't remove stem
    ///     )
    /// }
    /// ```
    public struct Property: Sendable {
        /// Sets the property to a new value.
        public let set: @Sendable (File.Path, String) -> File.Path

        /// Removes the property from the path.
        public let remove: @Sendable (File.Path) -> File.Path

        /// Creates a new property.
        public init(
            set: @escaping @Sendable (File.Path, String) -> File.Path,
            remove: @escaping @Sendable (File.Path) -> File.Path
        ) {
            self.set = set
            self.remove = remove
        }
    }

    // MARK: - Modification

    /// Returns path with property set to value.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/tmp/data.json"
    /// let txt = path.with(.extension, "txt")  // /tmp/data.txt
    /// let renamed = path.with(.lastComponent, "config.json")  // /tmp/config.json
    /// ```
    @inlinable
    public func with(_ property: Property, _ value: String) -> Self {
        property.set(self, value)
    }

    /// Returns path with property removed.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/tmp/data.json"
    /// let noExt = path.removing(.extension)  // /tmp/data
    /// ```
    @inlinable
    public func removing(_ property: Property) -> Self {
        property.remove(self)
    }
}

// MARK: - Built-in Properties

extension File.Path.Property {
    /// The file extension.
    public static let `extension` = Self(
        set: { path, value in
            var copy = path._path
            copy.extension = value
            return File.Path(__unchecked: (), copy)
        },
        remove: { path in
            var copy = path._path
            copy.extension = nil
            return File.Path(__unchecked: (), copy)
        }
    )

    /// The last path component (filename or directory name).
    public static let lastComponent = Self(
        set: { path, value in
            guard let parent = path.parent else {
                return File.Path(__unchecked: (), value)
            }
            return parent.appending(value)
        },
        remove: { path in
            path.parent ?? path
        }
    )
}

// ============================================================
// MARK: - File.Path.swift
// ============================================================

//
//  File.Path.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import SystemPackage

// MARK: - Appending (Convenience Methods)

extension File.Path {
    /// Appends a string component to this path.
    ///
    /// ```swift
    /// let path: File.Path = "/usr/local"
    /// let bin = path.appending("bin")  // "/usr/local/bin"
    /// ```
    @inlinable
    public func appending(_ string: String) -> File.Path {
        File.Path(self, appending: string)
    }

    /// Appends a validated component to this path.
    ///
    /// ```swift
    /// let component = try File.Path.Component("config.json")
    /// let full = basePath.appending(component)
    /// ```
    @inlinable
    public func appending(_ component: Component) -> File.Path {
        File.Path(self, appending: component)
    }

    /// Appends another path to this path.
    ///
    /// ```swift
    /// let base: File.Path = "/var/log"
    /// let sub: File.Path = "app/errors"
    /// let full = base.appending(sub)  // "/var/log/app/errors"
    /// ```
    @inlinable
    public func appending(_ other: File.Path) -> File.Path {
        File.Path(self, appending: other)
    }
}

extension File.Path {
    // MARK: - Components

    /// All path components as an array.
    @inlinable
    public var components: [Component] {
        _path.components.map { Component(__unchecked: $0) }
    }

    /// Number of path components.
    @inlinable
    public var count: Int {
        _path.components.count
    }

    // MARK: - Prefix/Relative

    /// Returns true if this path starts with the given prefix.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/usr/local/bin/swift"
    /// path.hasPrefix("/usr/local")  // true
    /// path.hasPrefix("/var")        // false
    /// ```
    @inlinable
    public func hasPrefix(_ other: File.Path) -> Bool {
        let selfComponents = Array(_path.components)
        let otherComponents = Array(other._path.components)

        guard otherComponents.count <= selfComponents.count else {
            return false
        }

        return zip(selfComponents, otherComponents).allSatisfy { $0 == $1 }
    }

    /// Returns the relative path from a base path, or nil if base is not a prefix.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/usr/local/bin/swift"
    /// let rel = path.relative(to: "/usr/local")  // "bin/swift"
    /// ```
    @inlinable
    public func relative(to base: File.Path) -> File.Path? {
        guard hasPrefix(base) else { return nil }

        let selfComponents = Array(_path.components)
        let baseCount = base._path.components.count

        guard baseCount < selfComponents.count else {
            // Same path
            return nil
        }

        var result = SystemPackage.FilePath()
        for component in selfComponents.dropFirst(baseCount) {
            result.append(component)
        }

        guard !result.isEmpty else { return nil }
        return File.Path(__unchecked: (), result)
    }
}

// MARK: - CustomStringConvertible

extension File.Path: CustomStringConvertible {
    @inlinable
    public var description: String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Path: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Path(\(string.debugDescription))"
    }
}

// MARK: - File.Path.Component Protocol Conformances

extension File.Path.Component: CustomStringConvertible {
    @inlinable
    public var description: String {
        string
    }
}

extension File.Path.Component: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Path.Component(\(string.debugDescription))"
    }
}

extension File.Path.Component.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Component is empty"
        case .containsPathSeparator:
            return "Component contains path separator"
        case .containsControlCharacters:
            return "Component contains control characters"
        case .invalid:
            return "Component is invalid"
        }
    }
}

extension File.Path.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Path is empty"
        case .containsControlCharacters:
            return "Path contains control characters"
        }
    }
}

// ============================================================
// MARK: - File.System.Stat.swift
// ============================================================

//
//  File.System.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.System.Stat {
    /// Checks if the path is a regular file.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a regular file, `false` otherwise.
    public static func isFile(at path: File.Path) -> Bool {
        guard let info = try? info(at: path) else { return false }
        return info.type == .regular
    }

    /// Checks if the path is a directory.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a directory, `false` otherwise.
    public static func isDirectory(at path: File.Path) -> Bool {
        guard let info = try? info(at: path) else { return false }
        return info.type == .directory
    }

    /// Checks if the path is a symbolic link.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path is a symbolic link, `false` otherwise.
    public static func isSymlink(at path: File.Path) -> Bool {
        guard let info = try? lstatInfo(at: path) else { return false }
        return info.type == .symbolicLink
    }
}

// ============================================================
// MARK: - File.swift
// ============================================================

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


// ============================================================
// MARK: - exports.swift
// ============================================================

//
//  exports.swift
//  swift-file-system
//
//  File System module exports
//

@_exported public import File_System_Async
@_exported public import File_System_Primitives
