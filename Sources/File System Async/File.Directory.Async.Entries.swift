//
//  File.Directory.Async.Entries.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import AsyncAlgorithms

// MARK: - Entries API

extension File.Directory.Async {
    /// Returns an async sequence of directory entries.
    ///
    /// This provides streaming iteration with proper backpressure and
    /// cancellation support.
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
    /// - Breaking from the loop cancels the producer
    /// - Use `iterator.terminate()` for explicit cleanup if needed
    /// - Resources are always cleaned up regardless of exit path
    public func entries(at path: File.Path) -> Entries {
        Entries(path: path, io: io)
    }
}

// MARK: - Entries AsyncSequence

extension File.Directory.Async {
    /// An AsyncSequence of directory entries with explicit lifecycle control.
    ///
    /// ## Backpressure
    /// Uses 1-element buffering: producer waits for consumer to pull before reading next.
    /// This ensures memory-bounded operation even for large directories.
    ///
    /// ## Termination
    /// The producer is cancelled when:
    /// - The iterator is deallocated (for-in loop completes or breaks)
    /// - `next()` is called after cancellation
    /// - `terminate()` is called explicitly
    ///
    /// ## Resource Cleanup
    /// The underlying directory iterator is always closed via `io.run`
    /// regardless of how iteration ends.
    public struct Entries: AsyncSequence, Sendable {
        public typealias Element = File.Directory.Entry

        let path: File.Path
        let io: File.IO.Executor

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(path: path, io: io)
        }
    }
}
