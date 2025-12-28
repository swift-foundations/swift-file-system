//
//  File.System+Async.swift
//  swift-file-system
//
//  Async overloads for sync operations.
//  Swift disambiguates by context - use `await` for async version.
//
//  These methods use `IO.Error<SpecificError>` to preserve the specific
//  operation error type while also capturing executor/thread/cancellation errors.
//

// MARK: - Read

extension File.System.Read {
    /// Stream file bytes asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await chunk in File.System.Read.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - options: Byte streaming options.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of byte chunks.
    public static func bytes(
        from path: File.Path,
        options: File.System.Read.Async.Options = .init(),
        fs: File.System.Async = .async
    ) -> File.System.Read.Async.Sequence {
        Async(fs: fs).bytes(from: path, options: options)
    }
}

extension File.System.Read.Full {
    /// Reads entire file contents asynchronously.
    ///
    /// ```swift
    /// let data = try await File.System.Read.Full.read(from: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for read errors, or `.executor`/`.cancelled` for I/O errors.
    public static func read(
        from path: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Read.Full.Error>>) -> [UInt8] {
        try await fs.run { () throws(File.System.Read.Full.Error) -> [UInt8] in
            try read(from: path)
        }
    }
}

// MARK: - Write

extension File.System.Write.Atomic {
    /// Writes data atomically to a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Write.Atomic.write(data, to: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for write errors, or `.executor`/`.cancelled` for I/O errors.
    public static func write(
        _ bytes: [UInt8],
        to path: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Atomic.Error>>) {
        try await fs.run { () throws(File.System.Write.Atomic.Error) in
            try write(bytes.span, to: path, options: options)
        }
    }
}

// MARK: - Streaming Write (Sync Sequence)

extension File.System.Write.Streaming {
    /// Writes a sequence of byte chunks to a file asynchronously.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    /// Accepts any `Sequence where Element == [UInt8]`, including lazy sequences.
    ///
    /// ```swift
    /// // Array of arrays
    /// let chunks: [[UInt8]] = generateChunks()
    /// try await File.System.Write.Streaming.write(chunks, to: path)
    ///
    /// // Lazy sequence (memory-efficient generation)
    /// let lazyChunks = stride(from: 0, to: 100, by: 1).lazy.map { _ in
    ///     [UInt8](repeating: 0, count: 64 * 1024)
    /// }
    /// try await File.System.Write.Streaming.write(lazyChunks, to: path)
    /// ```
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write
    ///   - path: Destination file path
    ///   - options: Write options (atomic by default)
    ///   - io: IO executor for offloading blocking work
    /// - Throws: `IO.Error<Error>` with `.operation` for write errors, or `.executor`/`.cancelled` for I/O errors.
    public static func write<Chunks: Sequence & Sendable>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>)
    where Chunks.Element == [UInt8] {
        try await fs.run { () throws(File.System.Write.Streaming.Error) in
            try write(chunks, to: path, options: options)
        }
    }
}

extension File.System.Write.Append {
    /// Appends data to a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Write.Append.append(data, to: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for append errors, or `.executor`/`.cancelled` for I/O errors.
    public static func append(
        _ bytes: [UInt8],
        to path: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Append.Error>>) {
        try await fs.run { () throws(File.System.Write.Append.Error) in
            try append(bytes.span, to: path)
        }
    }
}

// MARK: - Copy

extension File.System.Copy {
    /// Copies a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Copy.copy(from: source, to: destination)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for copy errors, or `.executor`/`.cancelled` for I/O errors.
    public static func copy(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Copy.Error>>) {
        try await fs.run { () throws(File.System.Copy.Error) in
            try copy(from: source, to: destination, options: options)
        }
    }
}

// MARK: - Move

extension File.System.Move {
    /// Moves or renames a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Move.move(from: source, to: destination)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for move errors, or `.executor`/`.cancelled` for I/O errors.
    public static func move(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Move.Error>>) {
        try await fs.run { () throws(File.System.Move.Error) in
            try move(from: source, to: destination, options: options)
        }
    }
}

// MARK: - Delete

extension File.System.Delete {
    /// Deletes a file or directory asynchronously.
    ///
    /// ```swift
    /// try await File.System.Delete.delete(at: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for delete errors, or `.executor`/`.cancelled` for I/O errors.
    public static func delete(
        at path: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Delete.Error>>) {
        try await fs.run { () throws(File.System.Delete.Error) in
            try delete(at: path, options: options)
        }
    }
}

// MARK: - Create Directory

extension File.System.Create.Directory {
    /// Creates a directory asynchronously.
    ///
    /// ```swift
    /// try await File.System.Create.Directory.create(at: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for create errors, or `.executor`/`.cancelled` for I/O errors.
    public static func create(
        at path: File.Path,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Create.Directory.Error>>) {
        try await fs.run { () throws(File.System.Create.Directory.Error) in
            try create(at: path, options: options)
        }
    }
}

// MARK: - Stat

extension File.System.Stat {
    /// Gets file metadata asynchronously.
    ///
    /// ```swift
    /// let info = try await File.System.Stat.info(at: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for stat errors, or `.executor`/`.cancelled` for I/O errors.
    public static func info(
        at path: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Stat.Error>>) -> File.System.Metadata.Info {
        try await fs.run { () throws(File.System.Stat.Error) -> File.System.Metadata.Info in
            try info(at: path)
        }
    }

    /// Checks if a path exists asynchronously.
    ///
    /// ```swift
    /// let exists = await File.System.Stat.exists(at: path)
    /// ```
    public static func exists(
        at path: File.Path,
        fs: File.System.Async = .async
    ) async -> Bool {
        do {
            return try await fs.run { exists(at: path) }
        } catch {
            return false
        }
    }

    /// Checks if path is a file asynchronously.
    public static func isFile(
        at path: File.Path,
        fs: File.System.Async = .async
    ) async -> Bool {
        do {
            let metadata: File.System.Metadata.Info = try await fs.run {
                try File.System.Stat.info(at: path)
            }
            return metadata.type == .regular
        } catch {
            return false
        }
    }

    /// Checks if path is a directory asynchronously.
    public static func isDirectory(
        at path: File.Path,
        fs: File.System.Async = .async
    ) async -> Bool {
        do {
            let metadata: File.System.Metadata.Info = try await fs.run {
                try File.System.Stat.info(at: path)
            }
            return metadata.type == .directory
        } catch {
            return false
        }
    }

    /// Checks if path is a symlink asynchronously.
    public static func isSymlink(
        at path: File.Path,
        fs: File.System.Async = .async
    ) async -> Bool {
        do {
            let metadata: File.System.Metadata.Info = try await fs.run {
                try File.System.Stat.lstatInfo(at: path)
            }
            return metadata.type == .symbolicLink
        } catch {
            return false
        }
    }
}

// MARK: - Directory Contents

extension File.Directory.Contents {
    /// Lists directory contents asynchronously.
    ///
    /// ```swift
    /// let entries = try await File.Directory.Contents.list(at: path)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for list errors, or `.executor`/`.cancelled` for I/O errors.
    public static func list(
        at directory: File.Directory,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>) -> [File.Directory.Entry] {
        try await fs.run { () throws(File.Directory.Contents.Error) -> [File.Directory.Entry] in
            try list(at: directory)
        }
    }
}

// MARK: - Directory Walk

extension File.Directory.Walk {
    /// Recursively walks a directory tree asynchronously.
    ///
    /// ```swift
    /// let entries = try await File.Directory.Walk.walk(at: directory)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for walk errors, or `.executor`/`.cancelled` for I/O errors.
    public static func walk(
        at directory: File.Directory,
        options: Options = .init(),
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Walk.Error>>) -> [File.Directory.Entry] {
        try await fs.run { () throws(File.Directory.Walk.Error) -> [File.Directory.Entry] in
            try walk(at: directory, options: options)
        }
    }
}

// MARK: - Links

extension File.System.Link.Symbolic {
    /// Creates a symbolic link asynchronously.
    ///
    /// ```swift
    /// try await File.System.Link.Symbolic.create(at: link, pointingTo: target)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for link errors, or `.executor`/`.cancelled` for I/O errors.
    public static func create(
        at path: File.Path,
        pointingTo target: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Link.Symbolic.Error>>) {
        try await fs.run { () throws(File.System.Link.Symbolic.Error) in
            try create(at: path, pointingTo: target)
        }
    }
}

extension File.System.Link.Hard {
    /// Creates a hard link asynchronously.
    ///
    /// ```swift
    /// try await File.System.Link.Hard.create(at: link, to: target)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for link errors, or `.executor`/`.cancelled` for I/O errors.
    public static func create(
        at path: File.Path,
        to existing: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Link.Hard.Error>>) {
        try await fs.run { () throws(File.System.Link.Hard.Error) in
            try create(at: path, to: existing)
        }
    }
}

extension File.System.Link.Read.Target {
    /// Reads symlink target asynchronously.
    ///
    /// ```swift
    /// let target = try await File.System.Link.Read.Target.target(of: link)
    /// ```
    ///
    /// - Throws: `IO.Error<Error>` with `.operation` for read errors, or `.executor`/`.cancelled` for I/O errors.
    public static func target(
        of path: File.Path,
        fs: File.System.Async = .async
    ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Link.Read.Target.Error>>) -> File.Path {
        try await fs.run { () throws(File.System.Link.Read.Target.Error) -> File.Path in
            try target(of: path)
        }
    }
}
