//
//  File.Stream.Byte.Async.Sequence.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import AsyncAlgorithms

// MARK: - Bytes API

extension File.Stream.Async {
    /// Stream file bytes with backpressure.
    ///
    /// ## Example
    /// ```swift
    /// let stream = File.Stream.Async(io: executor)
    /// for try await chunk in stream.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    ///
    /// ## Chunk Contract
    /// - Yields owned `[UInt8]` chunks (allocation per chunk is intentional)
    /// - Callers needing zero-allocation must use handle APIs directly
    /// - Chunk size is configurable; last chunk may be smaller
    ///
    /// ## Backpressure
    /// Producer suspends when consumer is slow (via AsyncChannel).
    public func bytes(
        from path: File.Path,
        options: File.Stream.Bytes.Async.Options = .init()
    ) -> File.Stream.Byte.Async.Sequence {
        File.Stream.Byte.Async.Sequence(path: path, chunkSize: options.chunkSize, io: io)
    }
}

// MARK: - Byte.Async.Sequence

extension File.Stream.Byte.Async {
    /// An AsyncSequence of byte chunks from a file.
    ///
    /// ## Memory Contract
    /// Each chunk is an owned `[UInt8]` array. This intentional allocation
    /// allows consumers to store, send, or process chunks without lifetime
    /// concerns. For zero-allocation streaming, use the handle APIs directly.
    ///
    /// ## Producer Lifecycle
    /// The producer is cancelled when:
    /// - The iterator is deallocated
    /// - `next()` is called after cancellation
    /// - `terminate()` is called explicitly
    public struct Sequence: AsyncSequence, Sendable {
        public typealias Element = [UInt8]

        let path: File.Path
        let chunkSize: Int
        let io: File.IO.Executor

        public func makeAsyncIterator() -> Iterator {
            Iterator.make(path: path, chunkSize: chunkSize, io: io)
        }
    }
}
