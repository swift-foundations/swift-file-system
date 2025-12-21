//
//  File.Directory.Async.Walk.Sequence.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import AsyncAlgorithms

// MARK: - Walk API

extension File.Directory.Async {
    /// Recursively walks a directory tree.
    ///
    /// ## Example
    /// ```swift
    /// let dir = File.Directory.Async(io: executor)
    /// for try await path in dir.walk(at: root) {
    ///     print(path)
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// First error wins - stops the walk and propagates to consumer.
    ///
    /// ## Cycle Detection
    /// When `followSymlinks` is true, tracks visited inodes to prevent infinite loops.
    public func walk(
        at root: File.Path,
        options: WalkOptions = WalkOptions()
    ) -> WalkSequence {
        WalkSequence(root: root, options: options, io: io)
    }
}

// MARK: - WalkSequence

extension File.Directory.Async {
    /// An AsyncSequence that recursively yields all paths in a directory tree.
    ///
    /// ## State Machine
    /// Uses a completion authority to ensure exactly one terminal state:
    /// `running` → `failed(Error)` | `cancelled` | `finished`
    ///
    /// ## Bounded Concurrency
    /// Concurrent directory reads are bounded by `maxConcurrency`.
    public struct WalkSequence: AsyncSequence, Sendable {
        public typealias Element = File.Path

        let root: File.Path
        let options: WalkOptions
        let io: File.IO.Executor

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator.make(root: root, options: options, io: io)
        }
    }
}
