//
//  File.Directory.Contents.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

// MARK: - Contents API

extension File.Directory.Async {
    /// Returns an async sequence of directory entries.
    ///
    /// This provides streaming iteration with proper cancellation support.
    /// Uses a pull-based design: consumer drives iteration, one `io.run` call
    /// per batch of entries.
    ///
    /// ## Example
    /// ```swift
    /// let dir = File.Directory.Async(io: executor)
    /// for try await entry in dir.entries(at: path) {
    ///     print(entry.name)
    /// }
    /// ```
    ///
    /// ## Termination
    /// - Breaking from the loop triggers cleanup via deinit (best-effort)
    /// - Use `iterator.terminate()` for explicit cleanup if needed
    /// - Resources are always cleaned up regardless of exit path
    public func entries(at path: File.Path) -> File.Directory.Contents.Async {
        File.Directory.Contents.Async(path: path, io: io, batchSize: 128)
    }

    /// Internal: Returns an async sequence with configurable batch size for benchmarking.
    internal func entries(at path: File.Path, batchSize: Int) -> File.Directory.Contents.Async {
        File.Directory.Contents.Async(path: path, io: io, batchSize: batchSize)
    }
}

// MARK: - Contents AsyncSequence

extension File.Directory.Contents {
    /// An AsyncSequence of directory entries with explicit lifecycle control.
    ///
    /// ## Design
    /// Pull-based iteration: consumer calls `next()`, which refills an internal
    /// buffer via a single `io.run` call when exhausted. No producer Task,
    /// no channel overhead.
    ///
    /// ## Batch Size
    /// Entries are read in batches (default 64) to amortize executor overhead.
    /// Tune via internal `entries(at:batchSize:)` for benchmarking.
    ///
    /// ## Termination
    /// The iterator transitions to `.finished` when:
    /// - All entries have been read
    /// - An error occurs
    /// - Task is cancelled
    /// - `terminate()` is called explicitly
    ///
    /// ## Resource Cleanup
    /// The underlying directory iterator is always closed via `io.run`
    /// regardless of how iteration ends.
    public struct Async: AsyncSequence, Sendable {
        public typealias Element = File.Directory.Entry

        let path: File.Path
        let io: File.IO.Executor
        let batchSize: Int

        public func makeAsyncIterator() -> Iterator {
            Iterator(path: path, io: io, batchSize: batchSize)
        }
    }
}
