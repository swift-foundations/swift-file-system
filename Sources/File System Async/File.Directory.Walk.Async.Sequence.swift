//
//  File.Directory.Walk.Async.Sequence.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
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
        at root: File.Directory,
        options: File.Directory.Walk.Async.Options = .init()
    ) -> File.Directory.Walk.Async.Sequence {
        File.Directory.Walk.Async.Sequence(root: root, options: options, io: io)
    }
}

// MARK: - Walk.Async.Sequence

extension File.Directory.Walk.Async {
    /// An AsyncSequence that recursively yields all paths in a directory tree.
    ///
    /// ## State Machine
    /// Uses a completion authority to ensure exactly one terminal state:
    /// `running` → `failed(Error)` | `cancelled` | `finished`
    ///
    /// ## Bounded Concurrency
    /// Concurrent directory reads are bounded by `maxConcurrency`.
    public struct Sequence: AsyncSequence, Sendable {
        public typealias Element = File.Path

        let root: File.Directory
        let options: Options
        let io: File.IO.Executor

        public func makeAsyncIterator() -> Iterator {
            Iterator.make(root: root, options: options, io: io)
        }
    }
}
