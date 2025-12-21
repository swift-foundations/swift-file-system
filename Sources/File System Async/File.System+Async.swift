//
//  File.System+Async.swift
//  swift-file-system
//
//  AsyncSequence streaming write implementation.
//

// MARK: - Streaming Write (AsyncSequence)

extension File.System.Write.Streaming {
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
                let maxSize = 1024 * 1024  // 1MB cap

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
                let maxSize = 1024 * 1024  // 1MB cap

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
