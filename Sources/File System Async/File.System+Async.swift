//
//  File.System+Async.swift
//  swift-file-system
//
//  Async overloads for sync operations.
//  Swift disambiguates by context - use `await` for async version.
//

// MARK: - Read

extension File.System.Read.Full {
    /// Reads entire file contents asynchronously.
    ///
    /// ```swift
    /// let data = try await File.System.Read.Full.read(from: path)
    /// ```
    public static func read(
        from path: File.Path,
        io: File.IO.Executor = .default
    ) async throws -> [UInt8] {
        try await io.run { try read(from: path) }
    }
}

// MARK: - Write

extension File.System.Write.Atomic {
    /// Writes data atomically to a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Write.Atomic.write(data, to: path)
    /// ```
    public static func write(
        _ bytes: [UInt8],
        to path: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run {
            try bytes.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try write(span, to: path, options: options)
            }
        }
    }
}

// MARK: - Streaming Write

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
    public static func write<Chunks: Sequence & Sendable>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws where Chunks.Element == [UInt8] {
        try await io.run { try write(chunks, to: path, options: options) }
    }

    /// Writes an async sequence of byte chunks to a file.
    ///
    /// True streaming implementation - processes chunks as they arrive with bounded
    /// memory usage. Uses coalescing to reduce syscall overhead while maintaining
    /// memory efficiency.
    ///
    /// **Important - Chunk Ownership:** Chunks must not be mutated after being
    /// yielded. The implementation writes chunks immediately; mutating a chunk after
    /// yield can cause data corruption. Each `[UInt8]` chunk is treated as an
    /// owned, immutable value.
    ///
    /// ```swift
    /// try await File.System.Write.Streaming.write(asyncChunks, to: path)
    /// ```
    ///
    /// - Parameters:
    ///   - chunks: Async sequence of owned `[UInt8]` arrays. Must not be mutated after yield.
    ///   - path: Destination file path
    ///   - options: Write options (atomic by default)
    ///   - io: IO executor for offloading blocking work
    public static func write<Chunks: AsyncSequence & Sendable>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws where Chunks.Element == [UInt8] {
        #if os(Windows)
            try await writeAsyncStreamWindows(chunks, to: path, options: options, io: io)
        #else
            try await writeAsyncStreamPOSIX(chunks, to: path, options: options, io: io)
        #endif
    }

    #if !os(Windows)
    /// POSIX implementation of async streaming write.
    private static func writeAsyncStreamPOSIX<Chunks: AsyncSequence & Sendable>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options,
        io: File.IO.Executor
    ) async throws where Chunks.Element == [UInt8] {
        // Phase 1: Open
        let context = try await io.run {
            try POSIXStreaming.openForStreaming(path: path.string, options: options)
        }

        do {
            // Phase 2: Write chunks with coalescing
            var coalescingBuffer: [UInt8] = []
            coalescingBuffer.reserveCapacity(256 * 1024)  // Pre-allocate target size
            let targetSize = 256 * 1024  // 256KB target
            let maxSize = 1024 * 1024    // 1MB cap

            for try await chunk in chunks {
                try Task.checkCancellation()

                if chunk.count >= maxSize {
                    // Large chunk: flush buffer first, then write-through
                    if !coalescingBuffer.isEmpty {
                        // Transfer ownership to avoid allocation (consume + reinit)
                        let bufferToWrite = consume coalescingBuffer
                        coalescingBuffer = []
                        coalescingBuffer.reserveCapacity(targetSize)
                        try await io.run {
                            try bufferToWrite.withUnsafeBufferPointer { buffer in
                                let span = Span<UInt8>(_unsafeElements: buffer)
                                try POSIXStreaming.writeChunk(span, to: context)
                            }
                        }
                    }
                    // chunk is already a let constant from for-await, safe to capture
                    let chunkToWrite = chunk
                    try await io.run {
                        try chunkToWrite.withUnsafeBufferPointer { buffer in
                            let span = Span<UInt8>(_unsafeElements: buffer)
                            try POSIXStreaming.writeChunk(span, to: context)
                        }
                    }
                } else {
                    coalescingBuffer.append(contentsOf: chunk)
                    if coalescingBuffer.count >= targetSize {
                        let bufferToWrite = consume coalescingBuffer
                        coalescingBuffer = []
                        coalescingBuffer.reserveCapacity(targetSize)
                        try await io.run {
                            try bufferToWrite.withUnsafeBufferPointer { buffer in
                                let span = Span<UInt8>(_unsafeElements: buffer)
                                try POSIXStreaming.writeChunk(span, to: context)
                            }
                        }
                    }
                }
            }

            // Flush remaining
            if !coalescingBuffer.isEmpty {
                let bufferToWrite = consume coalescingBuffer
                try await io.run {
                    try bufferToWrite.withUnsafeBufferPointer { buffer in
                        let span = Span<UInt8>(_unsafeElements: buffer)
                        try POSIXStreaming.writeChunk(span, to: context)
                    }
                }
            }

            // Phase 3: Commit
            try await io.run { try POSIXStreaming.commit(context) }

        } catch {
            // Primary cleanup path - AWAITED
            try? await io.run { POSIXStreaming.cleanup(context) }
            throw error
        }
    }
    #endif

    #if os(Windows)
    /// Windows implementation of async streaming write.
    private static func writeAsyncStreamWindows<Chunks: AsyncSequence & Sendable>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options,
        io: File.IO.Executor
    ) async throws where Chunks.Element == [UInt8] {
        // Phase 1: Open
        let context = try await io.run {
            try WindowsStreaming.openForStreaming(path: path.string, options: options)
        }

        do {
            // Phase 2: Write chunks with coalescing
            var coalescingBuffer: [UInt8] = []
            coalescingBuffer.reserveCapacity(256 * 1024)  // Pre-allocate target size
            let targetSize = 256 * 1024  // 256KB target
            let maxSize = 1024 * 1024    // 1MB cap

            for try await chunk in chunks {
                try Task.checkCancellation()

                if chunk.count >= maxSize {
                    // Large chunk: flush buffer first, then write-through
                    if !coalescingBuffer.isEmpty {
                        // Transfer ownership to avoid allocation (consume + reinit)
                        let bufferToWrite = consume coalescingBuffer
                        coalescingBuffer = []
                        coalescingBuffer.reserveCapacity(targetSize)
                        try await io.run {
                            try bufferToWrite.withUnsafeBufferPointer { buffer in
                                let span = Span<UInt8>(_unsafeElements: buffer)
                                try WindowsStreaming.writeChunk(span, to: context)
                            }
                        }
                    }
                    let chunkToWrite = chunk
                    try await io.run {
                        try chunkToWrite.withUnsafeBufferPointer { buffer in
                            let span = Span<UInt8>(_unsafeElements: buffer)
                            try WindowsStreaming.writeChunk(span, to: context)
                        }
                    }
                } else {
                    coalescingBuffer.append(contentsOf: chunk)
                    if coalescingBuffer.count >= targetSize {
                        let bufferToWrite = consume coalescingBuffer
                        coalescingBuffer = []
                        coalescingBuffer.reserveCapacity(targetSize)
                        try await io.run {
                            try bufferToWrite.withUnsafeBufferPointer { buffer in
                                let span = Span<UInt8>(_unsafeElements: buffer)
                                try WindowsStreaming.writeChunk(span, to: context)
                            }
                        }
                    }
                }
            }

            // Flush remaining
            if !coalescingBuffer.isEmpty {
                let bufferToWrite = consume coalescingBuffer
                try await io.run {
                    try bufferToWrite.withUnsafeBufferPointer { buffer in
                        let span = Span<UInt8>(_unsafeElements: buffer)
                        try WindowsStreaming.writeChunk(span, to: context)
                    }
                }
            }

            // Phase 3: Commit
            try await io.run { try WindowsStreaming.commit(context) }

        } catch {
            // Primary cleanup path - AWAITED
            try? await io.run { WindowsStreaming.cleanup(context) }
            throw error
        }
    }
    #endif
}

extension File.System.Write.Append {
    /// Appends data to a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Write.Append.append(data, to: path)
    /// ```
    public static func append(
        _ bytes: [UInt8],
        to path: File.Path,
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run {
            try bytes.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try append(span, to: path)
            }
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
    public static func copy(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try copy(from: source, to: destination, options: options) }
    }
}

// MARK: - Move

extension File.System.Move {
    /// Moves or renames a file asynchronously.
    ///
    /// ```swift
    /// try await File.System.Move.move(from: source, to: destination)
    /// ```
    public static func move(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try move(from: source, to: destination, options: options) }
    }
}

// MARK: - Delete

extension File.System.Delete {
    /// Deletes a file or directory asynchronously.
    ///
    /// ```swift
    /// try await File.System.Delete.delete(at: path)
    /// ```
    public static func delete(
        at path: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try delete(at: path, options: options) }
    }
}

// MARK: - Create Directory

extension File.System.Create.Directory {
    /// Creates a directory asynchronously.
    ///
    /// ```swift
    /// try await File.System.Create.Directory.create(at: path)
    /// ```
    public static func create(
        at path: File.Path,
        options: Options = .init(),
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try create(at: path, options: options) }
    }
}

// MARK: - Stat

extension File.System.Stat {
    /// Gets file metadata asynchronously.
    ///
    /// ```swift
    /// let info = try await File.System.Stat.info(at: path)
    /// ```
    public static func info(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async throws -> File.System.Metadata.Info {
        try await io.run { try info(at: path) }
    }

    /// Checks if a path exists asynchronously.
    ///
    /// ```swift
    /// let exists = await File.System.Stat.exists(at: path)
    /// ```
    public static func exists(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async -> Bool {
        do {
            return try await io.run { exists(at: path) }
        } catch {
            return false
        }
    }

    /// Checks if path is a file asynchronously.
    public static func isFile(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async -> Bool {
        do {
            let metadata = try await io.run { try File.System.Stat.info(at: path) }
            return metadata.kind == .regular
        } catch {
            return false
        }
    }

    /// Checks if path is a directory asynchronously.
    public static func isDirectory(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async -> Bool {
        do {
            let metadata = try await io.run { try File.System.Stat.info(at: path) }
            return metadata.kind == .directory
        } catch {
            return false
        }
    }

    /// Checks if path is a symlink asynchronously.
    public static func isSymlink(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async -> Bool {
        do {
            let metadata = try await io.run { try File.System.Stat.lstatInfo(at: path) }
            return metadata.kind == .symbolicLink
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
    public static func list(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async throws -> [File.Directory.Entry] {
        try await io.run { try list(at: path) }
    }
}

// MARK: - Links

extension File.System.Link.Symbolic {
    /// Creates a symbolic link asynchronously.
    ///
    /// ```swift
    /// try await File.System.Link.Symbolic.create(at: link, pointingTo: target)
    /// ```
    public static func create(
        at path: File.Path,
        pointingTo target: File.Path,
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try create(at: path, pointingTo: target) }
    }
}

extension File.System.Link.Hard {
    /// Creates a hard link asynchronously.
    ///
    /// ```swift
    /// try await File.System.Link.Hard.create(at: link, to: target)
    /// ```
    public static func create(
        at path: File.Path,
        to existing: File.Path,
        io: File.IO.Executor = .default
    ) async throws {
        try await io.run { try create(at: path, to: existing) }
    }
}

extension File.System.Link.ReadTarget {
    /// Reads symlink target asynchronously.
    ///
    /// ```swift
    /// let target = try await File.System.Link.ReadTarget.target(of: link)
    /// ```
    public static func target(
        of path: File.Path,
        io: File.IO.Executor = .default
    ) async throws -> File.Path {
        try await io.run { try target(of: path) }
    }
}
