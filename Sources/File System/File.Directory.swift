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
    /// - Parameter recursive: Whether to create intermediate directories recursively.
    /// - Throws: `File.System.Create.Directory.Error` on failure.
    public func create(recursive: Bool = false) throws(File.System.Create.Directory.Error) {
        let options = File.System.Create.Directory.Options(createIntermediates: recursive)
        try File.System.Create.Directory.create(at: path, options: options)
    }

    /// Creates the directory.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.System.Create.Directory.Error>` on failure.
    public func create(
        recursive: Bool = false
    ) async throws(File.IO.Error<File.System.Create.Directory.Error>) {
        let options = File.System.Create.Directory.Options(createIntermediates: recursive)
        try await File.System.Create.Directory.create(at: path, options: options)
    }

    /// Deletes the directory.
    ///
    /// - Parameter recursive: Whether to delete contents recursively.
    /// - Throws: `File.System.Delete.Error` on failure.
    public func delete(recursive: Bool = false) throws(File.System.Delete.Error) {
        let options = File.System.Delete.Options(recursive: recursive)
        try File.System.Delete.delete(at: path, options: options)
    }

    /// Deletes the directory.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.System.Delete.Error>` on failure.
    public func delete(
        recursive: Bool = false
    ) async throws(File.IO.Error<File.System.Delete.Error>) {
        let options = File.System.Delete.Options(recursive: recursive)
        try await File.System.Delete.delete(at: path, options: options)
    }

    /// Copies the directory to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Returns: A `File.Directory` representing the copy at the destination.
    /// - Throws: `File.System.Copy.Error` on failure.
    @discardableResult
    public func copy(
        to destination: File.Path,
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
    public func copy(
        to destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File.Directory {
        try File.System.Copy.copy(from: path, to: destination.path, options: options)
        return destination
    }

    /// Copies the directory to a destination path.
    ///
    /// Async variant.
    /// - Returns: A `File.Directory` representing the copy at the destination.
    /// - Throws: `File.IO.Error<File.System.Copy.Error>` on failure.
    @discardableResult
    public func copy(
        to destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws(File.IO.Error<File.System.Copy.Error>) -> File.Directory {
        try await File.System.Copy.copy(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    /// Copies the directory to a destination.
    ///
    /// Async variant.
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.IO.Error<File.System.Copy.Error>` on failure.
    @discardableResult
    public func copy(
        to destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) async throws(File.IO.Error<File.System.Copy.Error>) -> File.Directory {
        try await File.System.Copy.copy(from: path, to: destination.path, options: options)
        return destination
    }

    /// Moves the directory to a destination path.
    ///
    /// - Parameters:
    ///   - destination: The destination path.
    ///   - options: Move options (overwrite).
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.System.Move.Error` on failure.
    @discardableResult
    public func move(
        to destination: File.Path,
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
    public func move(
        to destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        try File.System.Move.move(from: path, to: destination.path, options: options)
        return destination
    }

    /// Moves the directory to a destination path.
    ///
    /// Async variant.
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
    public func move(
        to destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws(File.IO.Error<File.System.Move.Error>) -> File.Directory {
        try await File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    /// Moves the directory to a destination.
    ///
    /// Async variant.
    /// - Returns: The destination `File.Directory`.
    /// - Throws: `File.IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
    public func move(
        to destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) async throws(File.IO.Error<File.System.Move.Error>) -> File.Directory {
        try await File.System.Move.move(from: path, to: destination.path, options: options)
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
    public func rename(
        to newName: String,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        guard let parent = path.parent else {
            throw .sourceNotFound(path)
        }
        let destination = parent.appending(newName)
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    /// Renames the directory within the same parent directory.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.System.Move.Error>` on failure.
    @discardableResult
    public func rename(
        to newName: String,
        options: File.System.Move.Options = .init()
    ) async throws(File.IO.Error<File.System.Move.Error>) -> File.Directory {
        guard let parent = path.parent else {
            throw .operation(.sourceNotFound(path))
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
        get throws(File.System.Stat.Error) {
            try File.System.Stat.info(at: path)
        }
    }

    /// Returns the directory permissions.
    ///
    /// - Throws: `File.System.Stat.Error` on failure.
    public var permissions: File.System.Metadata.Permissions {
        get throws(File.System.Stat.Error) {
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
    public func contents() throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
        try File.Directory.Contents.list(at: self)
    }

    /// Returns the contents of the directory.
    ///
    /// Async variant. Use `entries()` for true streaming iteration.
    /// - Throws: `File.IO.Error<File.Directory.Contents.Error>` on failure.
    public func contents() async throws(File.IO.Error<File.Directory.Contents.Error>) -> [File
        .Directory.Entry]
    {
        try await File.Directory.Contents.list(at: self)
    }

    /// Returns all files in the directory.
    ///
    /// - Returns: An array of files.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public func files() throws(File.Directory.Contents.Error) -> [File] {
        try contents()
            .filter { $0.type == .file }
            .compactMap { $0.pathIfValid.map { File($0) } }
    }

    /// Returns all files in the directory.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.Directory.Contents.Error>` on failure.
    public func files() async throws(File.IO.Error<File.Directory.Contents.Error>) -> [File] {
        try await contents()
            .filter { $0.type == .file }
            .compactMap { $0.pathIfValid.map { File($0) } }
    }

    /// Returns all subdirectories in the directory.
    ///
    /// - Returns: An array of directories.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public func subdirectories() throws(File.Directory.Contents.Error) -> [File.Directory] {
        try contents()
            .filter { $0.type == .directory }
            .compactMap { $0.pathIfValid.map { File.Directory($0) } }
    }

    /// Returns all subdirectories in the directory.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.Directory.Contents.Error>` on failure.
    public func subdirectories() async throws(File.IO.Error<File.Directory.Contents.Error>) -> [File
        .Directory]
    {
        try await contents()
            .filter { $0.type == .directory }
            .compactMap { $0.pathIfValid.map { File.Directory($0) } }
    }

    /// Returns whether the directory is empty.
    ///
    /// - Returns: `true` if the directory contains no entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public var isEmpty: Bool {
        get throws(File.Directory.Contents.Error) {
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
    ) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
        try File.Directory.Walk.walk(at: self, options: options)
    }

    /// Recursively walks the directory tree and returns all entries.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.Directory.Walk.Error>` on failure.
    public func walk(
        options: File.Directory.Walk.Options = .init()
    ) async throws(File.IO.Error<File.Directory.Walk.Error>) -> [File.Directory.Entry] {
        try await File.Directory.Walk.walk(at: self, options: options)
    }

    /// Recursively walks the directory tree and returns all files.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all files found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public func walkFiles(
        options: File.Directory.Walk.Options = .init()
    ) throws(File.Directory.Walk.Error) -> [File] {
        try walk(options: options)
            .filter { $0.type == .file }
            .compactMap { $0.pathIfValid.map { File($0) } }
    }

    /// Recursively walks the directory tree and returns all files.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.Directory.Walk.Error>` on failure.
    public func walkFiles(
        options: File.Directory.Walk.Options = .init()
    ) async throws(File.IO.Error<File.Directory.Walk.Error>) -> [File] {
        try await walk(options: options)
            .filter { $0.type == .file }
            .compactMap { $0.pathIfValid.map { File($0) } }
    }

    /// Recursively walks the directory tree and returns all subdirectories.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all directories found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public func walkDirectories(
        options: File.Directory.Walk.Options = .init()
    ) throws(File.Directory.Walk.Error) -> [File.Directory] {
        try walk(options: options)
            .filter { $0.type == .directory }
            .compactMap { $0.pathIfValid.map { File.Directory($0) } }
    }

    /// Recursively walks the directory tree and returns all subdirectories.
    ///
    /// Async variant.
    /// - Throws: `File.IO.Error<File.Directory.Walk.Error>` on failure.
    public func walkDirectories(
        options: File.Directory.Walk.Options = .init()
    ) async throws(File.IO.Error<File.Directory.Walk.Error>) -> [File.Directory] {
        try await walk(options: options)
            .filter { $0.type == .directory }
            .compactMap { $0.pathIfValid.map { File.Directory($0) } }
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
        String(path)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Directory: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Directory(\(String(path).debugDescription))"
    }
}
