//
//  File.Directory.Walk.Async.Sequence.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import AsyncAlgorithms
import Synchronization

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
        File.Directory.Walk.Async.Sequence(root: root, options: options, fs: fs)
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
    ///
    /// ## Fast Path
    /// When `maxConcurrency == 1` and `followSymlinks == false`, uses an optimized
    /// single-threaded traversal (fts on POSIX) that avoids TaskGroup/actor overhead.
    public struct Sequence: AsyncSequence, Sendable {
        public typealias Element = File.Path

        let root: File.Directory
        let options: Options
        let fs: File.System.Async

        /// Returns an iterator using either fast-path or concurrent walker.
        ///
        /// Strategy selection (internal, not user-configurable):
        /// 1. Fast-path when `maxConcurrency == 1` and `!followSymlinks`
        /// 2. Fast-path for small trees (heuristic: few subdirectories at root)
        /// 3. Concurrent otherwise
        public func makeAsyncIterator() -> Strategy.Iterator {
            // Explicit fast-path request via maxConcurrency == 1
            if FastPath.canUse(options: options) {
                return Strategy.Iterator(
                    .fastPath(FastPath.makeSequence(root: root, options: options, fs: fs))
                )
            }

            // Internal heuristic: use fast-path for small trees
            // where concurrency overhead exceeds parallelism benefit
            if FastPath.shouldUseForSmallTree(root: root, options: options) {
                return Strategy.Iterator(
                    .fastPath(FastPath.makeSequence(root: root, options: options, fs: fs))
                )
            }

            // Default: concurrent walker
            return Strategy.Iterator(
                .concurrent(Sequence.Iterator.make(root: root, options: options, fs: fs))
            )
        }
    }

    /// Namespace for strategy-based iteration.
    public enum Strategy {
        /// Concrete iterator for the current traversal strategy.
        typealias Concurrent = Sequence.Iterator

        fileprivate enum Kind {
            case fastPath(AsyncThrowingStream<File.Path, any Error>)
            case concurrent(Concurrent)
        }

        fileprivate enum State {
            case fastPath(AsyncThrowingStream<File.Path, any Error>.AsyncIterator)
            case concurrent(Concurrent)
        }

        /// Iterator that wraps either fast-path or concurrent implementation.
        public final class Iterator: AsyncIteratorProtocol {
            public typealias Element = File.Path

            private var state: State
            private let _isTerminated = Atomic<Bool>(false)

            fileprivate init(_ kind: Kind) {
                switch kind {
                case .fastPath(let stream):
                    self.state = .fastPath(stream.makeAsyncIterator())
                case .concurrent(let iterator):
                    self.state = .concurrent(iterator)
                }
            }

            public func next() async throws -> File.Path? {
                // Check termination before awaiting
                guard !_isTerminated.load(ordering: .acquiring) else { return nil }

                switch state {
                case .fastPath(var iterator):
                    let result = try await iterator.next()
                    // Update state with mutated iterator
                    state = .fastPath(iterator)

                    // TERMINATION BARRIER: check again after await
                    if _isTerminated.load(ordering: .acquiring) { return nil }

                    return result
                case .concurrent(let iterator):
                    // Concurrent iterator has its own termination handling
                    return try await iterator.next()
                }
            }

            /// Explicitly terminate the walk and wait for cleanup to complete.
            ///
            /// After this returns, subsequent calls to `next()` will return `nil`.
            /// For concurrent walks, this also waits for the producer to finish.
            public func terminate() async {
                // Set termination flag first - this ensures next() returns nil
                _isTerminated.store(true, ordering: .releasing)

                switch state {
                case .fastPath:
                    // Fast-path: flag is sufficient, stream will be abandoned
                    break
                case .concurrent(let iterator):
                    // Also terminate the underlying concurrent iterator
                    await iterator.terminate()
                }
            }
        }
    }
}
