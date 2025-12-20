// Concatenated export of: File System Async
// Generated: Sat Dec 20 21:08:09 CET 2025


// ============================================================
// MARK: - File.Directory.Async.Entries.Iterator.Async.swift
// ============================================================

//
//  File.Directory.Async.Entries.Iterator.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import AsyncAlgorithms

extension File.Directory.Async.Entries {
    /// The async iterator for directory entries.
    ///
    /// ## Explicit Termination
    /// Call `terminate()` for deterministic cleanup instead of relying on deinit.
    /// This is especially important in contexts where deinit timing is uncertain.
    public final class AsyncIterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncThrowingChannel<Element, any Error>
        private var channelIterator: AsyncThrowingChannel<Element, any Error>.AsyncIterator
        private let producerTask: Task<Void, Never>
        private var isFinished = false

        init(path: File.Path, io: File.IO.Executor) {
            let channel = AsyncThrowingChannel<Element, any Error>()
            self.channel = channel
            self.channelIterator = channel.makeAsyncIterator()

            self.producerTask = Task {
                await Self.runProducer(path: path, io: io, channel: channel)
            }
        }

        deinit {
            producerTask.cancel()
        }

        public func next() async throws -> Element? {
            guard !isFinished else { return nil }

            do {
                try Task.checkCancellation()
                let result = try await channelIterator.next()
                if result == nil {
                    isFinished = true
                }
                return result
            } catch {
                isFinished = true
                producerTask.cancel()
                throw error
            }
        }

        /// Explicitly terminate iteration and release resources.
        ///
        /// Use this for deterministic cleanup instead of relying on deinit.
        /// Safe to call multiple times (idempotent).
        public func terminate() {
            guard !isFinished else { return }
            isFinished = true
            producerTask.cancel()
            channel.finish()  // Consumer's next() returns nil immediately
        }

        // MARK: - Producer

        private static func runProducer(
            path: File.Path,
            io: File.IO.Executor,
            channel: AsyncThrowingChannel<Element, any Error>
        ) async {
            // Open iterator via io.run (blocking operation)
            let iteratorResult: Result<IteratorBox, any Error> = await {
                do {
                    let box = try await io.run {
                        let iterator = try File.Directory.Iterator.open(at: path)
                        return IteratorBox(iterator)
                    }
                    return .success(box)
                } catch {
                    return .failure(error)
                }
            }()

            switch iteratorResult {
            case .failure(let error):
                channel.fail(error)
                return

            case .success(let box):
                // Stream entries with batching to reduce executor overhead
                do {
                    let batchSize = 64

                    while true {
                        try Task.checkCancellation()

                        // Read batch of entries via single io.run call
                        let batch: [Element] = try await io.run {
                            var entries: [Element] = []
                            entries.reserveCapacity(batchSize)
                            for _ in 0..<batchSize {
                                guard let entry = try box.next() else { break }
                                entries.append(entry)
                            }
                            return entries
                        }

                        if batch.isEmpty {
                            // End of directory
                            break
                        }

                        try Task.checkCancellation()

                        // Send batch entries with backpressure
                        for entry in batch {
                            await channel.send(entry)
                        }
                    }

                    // Clean close
                    await closeIterator(box, io: io)
                    channel.finish()

                } catch is CancellationError {
                    // Cancelled - clean up resources
                    await closeIterator(box, io: io)
                    channel.finish()

                } catch {
                    // Error during iteration
                    await closeIterator(box, io: io)
                    channel.fail(error)
                }
            }
        }

        private static func closeIterator(_ box: IteratorBox, io: File.IO.Executor) async {
            _ = try? await io.run {
                box.close()
            }
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Entries.Iterator.Box.swift
// ============================================================

//
//  File.Directory.Async.Entries.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory.Async.Entries {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// Uses UnsafeMutablePointer for stable address with ~Copyable type,
    /// similar to HandleBox pattern.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `io.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern
    final class IteratorBox: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<File.Directory.Iterator>?

        init(_ iterator: consuming File.Directory.Iterator) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume iterator)
        }

        deinit {
            // Best-effort cleanup if not explicitly closed
            if let ptr = storage {
                let it = ptr.move()
                ptr.deallocate()
                it.close()
            }
        }

        func next() throws -> File.Directory.Entry? {
            guard let ptr = storage else {
                return nil
            }
            return try ptr.pointee.next()
        }

        func close() {
            guard let ptr = storage else { return }
            let it = ptr.move()
            ptr.deallocate()
            storage = nil
            it.close()
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Entries.swift
// ============================================================

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

// ============================================================
// MARK: - File.Directory.Async.Walk.Completion.Authority.swift
// ============================================================

//
//  File.Directory.Async.Walk.Completion.Authority.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// State machine ensuring exactly one terminal state.
///
/// States: `running` → `failed(Error)` | `cancelled` | `finished`
/// First transition out of `running` wins.
actor _CompletionAuthority {
    enum State {
        case running
        case failed(any Error)
        case cancelled
        case finished
    }

    private var state: State = .running

    var isComplete: Bool {
        if case .running = state { return false }
        return true
    }

    /// Attempt to transition to failed. First error wins.
    func fail(with error: any Error) {
        guard case .running = state else { return }
        state = .failed(error)
    }

    /// Attempt to transition to cancelled.
    func cancel() {
        guard case .running = state else { return }
        state = .cancelled
    }

    /// Complete and return final state.
    func complete() -> State {
        if case .running = state {
            state = .finished
        }
        return state
    }
}

// ============================================================
// MARK: - File.Directory.Async.Walk.Inode.Key.swift
// ============================================================

//
//  File.Directory.Async.Walk.Inode.Key.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Unique identifier for a file (device + inode).
struct _InodeKey: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
}

// ============================================================
// MARK: - File.Directory.Async.Walk.Options.swift
// ============================================================

//
//  File.Directory.Async.Walk.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory.Async {
    /// Options for recursive directory walking.
    public struct WalkOptions: Sendable {
        /// Maximum concurrent directory reads.
        public var maxConcurrency: Int

        /// Whether to follow symbolic links.
        ///
        /// When `true`, cycle detection via inode tracking is enabled.
        public var followSymlinks: Bool

        /// Creates walk options.
        ///
        /// - Parameters:
        ///   - maxConcurrency: Maximum concurrent reads (default: 8).
        ///   - followSymlinks: Follow symlinks (default: false).
        public init(
            maxConcurrency: Int = 8,
            followSymlinks: Bool = false
        ) {
            self.maxConcurrency = max(1, maxConcurrency)
            self.followSymlinks = followSymlinks
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Walk.Sequence.Iterator.Async.swift
// ============================================================

//
//  File.Directory.Async.Walk.Sequence.Iterator.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import AsyncAlgorithms

extension File.Directory.Async.WalkSequence {
    /// The async iterator for directory walk.
    public final class AsyncIterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncThrowingChannel<Element, any Error>
        private var channelIterator: AsyncThrowingChannel<Element, any Error>.AsyncIterator
        private let producerTask: Task<Void, Never>
        private var isFinished = false

        init(root: File.Path, options: File.Directory.Async.WalkOptions, io: File.IO.Executor) {
            let channel = AsyncThrowingChannel<Element, any Error>()
            self.channel = channel
            self.channelIterator = channel.makeAsyncIterator()

            self.producerTask = Task {
                await Self.runWalk(root: root, options: options, io: io, channel: channel)
            }
        }

        deinit {
            producerTask.cancel()
        }

        public func next() async throws -> Element? {
            guard !isFinished else { return nil }

            do {
                try Task.checkCancellation()
                let result = try await channelIterator.next()
                if result == nil {
                    isFinished = true
                }
                return result
            } catch {
                isFinished = true
                producerTask.cancel()
                throw error
            }
        }

        /// Explicitly terminate the walk.
        public func terminate() {
            guard !isFinished else { return }
            isFinished = true
            producerTask.cancel()
            channel.finish()  // Consumer's next() returns nil immediately
        }

        // MARK: - Walk Implementation

        private static func runWalk(
            root: File.Path,
            options: File.Directory.Async.WalkOptions,
            io: File.IO.Executor,
            channel: AsyncThrowingChannel<Element, any Error>
        ) async {
            let state = _WalkState(maxConcurrency: options.maxConcurrency)
            let authority = _CompletionAuthority()

            // Enqueue root
            await state.enqueue(root)

            // Process directories until done
            await withTaskGroup(of: Void.self) { group in
                while await state.hasWork {
                    // Check for cancellation
                    if Task.isCancelled {
                        break
                    }

                    // Check for completion
                    if await authority.isComplete {
                        break
                    }

                    // Try to get a directory to process
                    guard let dir = await state.dequeue() else {
                        // No dirs in queue - wait for active workers
                        await state.waitForWorkOrCompletion()
                        continue
                    }

                    // Acquire semaphore slot
                    await state.acquireSemaphore()

                    // Spawn worker task
                    group.addTask {
                        await Self.processDirectory(
                            dir,
                            options: options,
                            io: io,
                            state: state,
                            authority: authority,
                            channel: channel
                        )
                        await state.releaseSemaphore()
                    }
                }

                // Cancel remaining work if authority completed with error
                group.cancelAll()
            }

            // Finish channel based on final state
            let finalState = await authority.complete()
            switch finalState {
            case .finished, .cancelled:
                channel.finish()
            case .failed(let error):
                channel.fail(error)
            case .running:
                // Should not happen - treat as finished
                channel.finish()
            }
        }

        private static func processDirectory(
            _ dir: File.Path,
            options: File.Directory.Async.WalkOptions,
            io: File.IO.Executor,
            state: _WalkState,
            authority: _CompletionAuthority,
            channel: AsyncThrowingChannel<Element, any Error>
        ) async {
            // Check if already done
            guard await !authority.isComplete else {
                await state.decrementActive()  // Don't leak worker count
                return
            }

            // Open iterator
            let boxResult: Result<IteratorBox, any Error> = await {
                do {
                    let box = try await io.run {
                        let iterator = try File.Directory.Iterator.open(at: dir)
                        return IteratorBox(iterator)
                    }
                    return .success(box)
                } catch {
                    return .failure(error)
                }
            }()

            guard case .success(let box) = boxResult else {
                if case .failure(let error) = boxResult {
                    await authority.fail(with: error)
                }
                await state.decrementActive()
                return
            }

            defer {
                Task {
                    _ = try? await io.run { box.close() }
                }
            }

            // Iterate directory with batching to reduce executor overhead
            do {
                let batchSize = 64

                while true {
                    // Check cancellation
                    if Task.isCancelled {
                        break
                    }

                    // Check completion
                    if await authority.isComplete {
                        break
                    }

                    // Read batch of entries via single io.run call
                    let batch: [File.Directory.Entry] = try await io.run {
                        var entries: [File.Directory.Entry] = []
                        entries.reserveCapacity(batchSize)
                        for _ in 0..<batchSize {
                            guard let entry = try box.next() else { break }
                            entries.append(entry)
                        }
                        return entries
                    }

                    guard !batch.isEmpty else { break }

                    // Process batch entries
                    for entry in batch {
                        // Send path to consumer
                        await channel.send(entry.path)

                        // Check if we should recurse
                        let shouldRecurse: Bool
                        if entry.type == .directory {
                            shouldRecurse = true
                        } else if options.followSymlinks && entry.type == .symbolicLink {
                            // Get inode for cycle detection
                            if let inode = await getInode(entry.path, io: io) {
                                shouldRecurse = await state.markVisited(inode)
                            } else {
                                shouldRecurse = false
                            }
                        } else {
                            shouldRecurse = false
                        }

                        if shouldRecurse {
                            await state.enqueue(entry.path)
                        }
                    }
                }
            } catch {
                await authority.fail(with: error)
            }

            await state.decrementActive()
        }

        private static func getInode(_ path: File.Path, io: File.IO.Executor) async -> _InodeKey? {
            do {
                return try await io.run {
                    // Use lstat to get the symlink's own inode, not its target's
                    let info = try File.System.Stat.lstatInfo(at: path)
                    return _InodeKey(device: info.deviceId, inode: info.inode)
                }
            } catch {
                return nil
            }
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Walk.Sequence.Iterator.Box.swift
// ============================================================

//
//  File.Directory.Async.Walk.Sequence.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory.Async.WalkSequence {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `io.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern
    final class IteratorBox: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<File.Directory.Iterator>?

        init(_ iterator: consuming File.Directory.Iterator) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume iterator)
        }

        deinit {
            if let ptr = storage {
                let it = ptr.move()
                ptr.deallocate()
                it.close()
            }
        }

        func next() throws -> File.Directory.Entry? {
            guard let ptr = storage else { return nil }
            return try ptr.pointee.next()
        }

        func close() {
            guard let ptr = storage else { return }
            let it = ptr.move()
            ptr.deallocate()
            storage = nil
            it.close()
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Walk.Sequence.swift
// ============================================================

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
            AsyncIterator(root: root, options: options, io: io)
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.Walk.State.swift
// ============================================================

//
//  File.Directory.Async.Walk.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Actor-protected state for the walk algorithm.
actor _WalkState {
    private var queue: [File.Path] = []
    private var activeWorkers: Int = 0
    private var visited: Set<_InodeKey> = []

    private let maxConcurrency: Int
    private var semaphoreValue: Int
    private var semaphoreWaiters: [CheckedContinuation<Void, Never>] = []
    private var completionWaiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrency: Int) {
        self.maxConcurrency = maxConcurrency
        self.semaphoreValue = maxConcurrency
    }

    var hasWork: Bool {
        !queue.isEmpty || activeWorkers > 0
    }

    func enqueue(_ path: File.Path) {
        queue.append(path)
        activeWorkers += 1
        // Wake one completion waiter
        if let waiter = completionWaiters.first {
            completionWaiters.removeFirst()
            waiter.resume()
        }
    }

    func dequeue() -> File.Path? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    func decrementActive() {
        activeWorkers = max(0, activeWorkers - 1)
        // Wake completion waiters
        if let waiter = completionWaiters.first {
            completionWaiters.removeFirst()
            waiter.resume()
        }
    }

    func waitForWorkOrCompletion() async {
        guard queue.isEmpty && activeWorkers > 0 else { return }
        await withCheckedContinuation { continuation in
            completionWaiters.append(continuation)
        }
    }

    /// Returns true if this is the first visit (should recurse), false if already visited (cycle).
    func markVisited(_ inode: _InodeKey) -> Bool {
        visited.insert(inode).inserted
    }

    func acquireSemaphore() async {
        if semaphoreValue > 0 {
            semaphoreValue -= 1
        } else {
            await withCheckedContinuation { continuation in
                semaphoreWaiters.append(continuation)
            }
        }
    }

    func releaseSemaphore() {
        if !semaphoreWaiters.isEmpty {
            semaphoreWaiters.removeFirst().resume()
        } else {
            semaphoreValue += 1
        }
    }
}

// ============================================================
// MARK: - File.Directory.Async.swift
// ============================================================

//
//  File.Directory.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory {
    /// Internal async directory implementation.
    ///
    /// Use the static methods instead:
    /// ```swift
    /// for try await entry in File.Directory.entries(at: path) {
    ///     print(entry.name)
    /// }
    /// ```
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async directory API with the given executor.
        init(io: File.IO.Executor = .default) {
            self.io = io
        }

        /// Lists directory contents (non-streaming).
        func contents(at path: File.Path) async throws -> [File.Directory.Entry] {
            try await io.run { try File.Directory.Contents.list(at: path) }
        }
    }

    // MARK: - Static Convenience Methods

    /// Stream directory entries asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await entry in File.Directory.entries(at: path) {
    ///     print(entry.name)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The directory path.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of directory entries.
    public static func entries(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) -> Async.Entries {
        Async(io: io).entries(at: path)
    }

    /// Lists directory contents asynchronously (non-streaming).
    ///
    /// - Parameters:
    ///   - path: The directory path.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: Array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public static func contents(
        at path: File.Path,
        io: File.IO.Executor = .default
    ) async throws -> [File.Directory.Entry] {
        try await Async(io: io).contents(at: path)
    }

    /// Walk directory tree recursively asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await entry in File.Directory.walk(at: path) {
    ///     print(entry.path)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The root directory path.
    ///   - options: Walk options.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of walk entries.
    public static func walk(
        at path: File.Path,
        options: Async.WalkOptions = .init(),
        io: File.IO.Executor = .default
    ) -> Async.WalkSequence {
        Async(io: io).walk(at: path, options: options)
    }
}

// ============================================================
// MARK: - File.Handle.Async.SendableBuffer.swift
// ============================================================

//
//  File.Handle.Async.SendableBuffer.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Wrapper to pass buffer pointers across Sendable boundaries.
///
/// SAFETY: The caller MUST ensure the underlying buffer remains valid
/// for the entire duration of the async call. This wrapper exists because
/// Swift's Sendable checking is more conservative than necessary for our
/// specific use case where the buffer is used synchronously within io.run.
struct _SendableBuffer: @unchecked Sendable {
    let pointer: UnsafeMutableRawBufferPointer
}

// ============================================================
// MARK: - File.Handle.Async.swift
// ============================================================

//
//  File.Handle.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Handle {
    /// An async-safe file handle wrapper.
    ///
    /// This actor provides async methods for file I/O operations while ensuring
    /// proper resource management and thread safety.
    ///
    /// ## Architecture
    /// The actor does NOT directly own the `File.Handle`. Instead:
    /// - The primitive `File.Handle` lives in the executor's handle store
    /// - This actor holds only a `HandleID` (Sendable token)
    /// - All operations go through `io.withHandle(id) { ... }`
    ///
    /// This design solves Swift 6's restrictions on non-Sendable, non-copyable
    /// types in actors by keeping the linear resource in a thread-safe store
    /// and never moving it across async boundaries.
    ///
    /// ## Close Contract
    /// - `close()` must be called explicitly for deterministic release
    /// - If actor deinitializes without `close()`, best-effort cleanup only
    /// - Close errors from deinit cleanup are discarded
    ///
    /// ## Example
    /// ```swift
    /// let handle = try await File.Handle.Async.open(path, mode: .read, io: executor)
    /// let data = try await handle.read(count: 1024)
    /// try await handle.close()
    /// ```
    public actor Async {
        /// The handle ID in the executor's store.
        private let id: File.IO.HandleID

        /// The executor that owns the handle store.
        private let io: File.IO.Executor

        /// Whether the handle has been closed.
        private var isClosed: Bool = false

        /// The path this handle was opened for (for diagnostics).
        public nonisolated let path: File.Path

        /// The mode this handle was opened with.
        public nonisolated let mode: File.Handle.Mode

        /// Creates an async handle by registering a primitive handle with the executor.
        ///
        /// - Parameters:
        ///   - handle: The primitive handle (ownership transferred to executor store).
        ///   - io: The executor that will manage this handle.
        /// - Throws: `ExecutorError.shutdownInProgress` if executor is shut down.
        public init(_ handle: consuming File.Handle, io: File.IO.Executor) throws {
            self.path = handle.path
            self.mode = handle.mode
            self.io = io
            self.id = try io.registerHandle(handle)
        }

        /// Internal initializer for when handle is already registered.
        internal init(
            id: File.IO.HandleID,
            path: File.Path,
            mode: File.Handle.Mode,
            io: File.IO.Executor
        ) {
            self.id = id
            self.path = path
            self.mode = mode
            self.io = io
        }

        deinit {
            // Only warn and cleanup if:
            // 1. We didn't explicitly call close()
            // 2. The handle is still in the store (not already cleaned up by shutdown)
            if !isClosed && io.isHandleValid(id) {
                #if DEBUG
                    print(
                        "Warning: File.Handle.Async deallocated without close() for path: \(path)"
                    )
                #endif
                // Best-effort cleanup - fire and forget
                // May be skipped during shutdown; errors discarded
                let io = self.io
                let id = self.id
                Task.detached {
                    try? await io.destroyHandle(id)
                }
            }
        }

        // MARK: - Opening

        /// Opens a file and returns an async handle.
        ///
        /// - Parameters:
        ///   - path: The path to the file.
        ///   - mode: The access mode.
        ///   - options: Additional options.
        ///   - io: The executor to use.
        /// - Returns: An async file handle.
        /// - Throws: `File.Handle.Error` on failure.
        public static func open(
            _ path: File.Path,
            mode: File.Handle.Mode,
            options: File.Handle.Options = [],
            io: File.IO.Executor
        ) async throws -> File.Handle.Async {
            // Open synchronously on the I/O executor, register immediately
            let id = try await io.run {
                let handle = try File.Handle.open(path, mode: mode, options: options)
                return try io.registerHandle(handle)
            }
            // Create the async wrapper with the registered ID
            return File.Handle.Async(id: id, path: path, mode: mode, io: io)
        }

        // MARK: - Reading

        /// Read into a caller-provided buffer.
        ///
        /// - Parameter destination: The buffer to read into.
        /// - Returns: Number of bytes read (0 at EOF).
        /// - Important: The buffer must remain valid until this call returns.
        public func read(into destination: UnsafeMutableRawBufferPointer) async throws -> Int {
            guard !isClosed else {
                throw File.Handle.Error.invalidHandle
            }
            // Wrap for Sendable - safe because buffer used synchronously in io.run
            let buffer = _SendableBuffer(pointer: destination)
            return try await io.withHandle(id) { handle in
                try handle.read(into: buffer.pointer)
            }
        }

        /// Convenience: read into a new array (allocates).
        ///
        /// - Parameter count: Maximum bytes to read.
        /// - Returns: The bytes read.
        public func read(count: Int) async throws -> [UInt8] {
            guard !isClosed else {
                throw File.Handle.Error.invalidHandle
            }
            return try await io.withHandle(id) { handle in
                try handle.read(count: count)
            }
        }

        // MARK: - Writing

        /// Write bytes from an array.
        ///
        /// - Parameter bytes: The bytes to write.
        public func write(_ bytes: [UInt8]) async throws {
            guard !isClosed else {
                throw File.Handle.Error.invalidHandle
            }
            try await io.withHandle(id) { handle in
                try bytes.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try handle.write(span)
                }
            }
        }

        // MARK: - Seeking

        /// Seek to a position.
        ///
        /// - Parameters:
        ///   - offset: The offset to seek to.
        ///   - origin: The origin for the seek.
        /// - Returns: The new position.
        @discardableResult
        public func seek(
            to offset: Int64,
            from origin: File.Handle.SeekOrigin = .start
        ) async throws -> Int64 {
            guard !isClosed else {
                throw File.Handle.Error.invalidHandle
            }
            return try await io.withHandle(id) { handle in
                try handle.seek(to: offset, from: origin)
            }
        }

        // MARK: - Sync

        /// Sync the file to disk.
        public func sync() async throws {
            guard !isClosed else {
                throw File.Handle.Error.invalidHandle
            }
            try await io.withHandle(id) { handle in
                try handle.sync()
            }
        }

        // MARK: - Close

        /// Close the handle.
        ///
        /// - Important: Must be called for deterministic release.
        /// - Note: Safe to call multiple times (idempotent).
        public func close() async throws {
            guard !isClosed else {
                return  // Already closed - idempotent
            }
            isClosed = true
            try await io.destroyHandle(id)
        }

        /// Whether the handle is still open.
        public var isOpen: Bool {
            !isClosed && io.isHandleValid(id)
        }
    }
}

// ============================================================
// MARK: - File.IO.AtomicCounter.swift
// ============================================================

//
//  File.IO.AtomicCounter.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

/// Thread-safe counter for generating unique IDs.
///
/// ## Safety Invariant
/// All mutations of `value` occur inside `withLock`, ensuring exclusive access.
final class _AtomicCounter: @unchecked Sendable {
    private let state: Mutex<UInt64>

    init() {
        self.state = Mutex(0)
    }

    func next() -> UInt64 {
        state.withLock { value in
            let result = value
            value += 1
            return result
        }
    }
}

// ============================================================
// MARK: - File.IO.Configuration.ThreadModel.swift
// ============================================================

//
//  File.IO.Configuration.ThreadModel.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Configuration {
    /// Thread model for executing I/O operations.
    public enum ThreadModel: Sendable {
        /// Cooperative thread pool using `Task.detached`.
        ///
        /// Uses Swift's default cooperative thread pool. Under sustained blocking I/O,
        /// this can starve unrelated async work.
        case cooperative

        /// Dedicated thread pool using `DispatchQueue`.
        ///
        /// Creates explicit dispatch queues with user-initiated QoS.
        /// Prevents blocking I/O from starving the cooperative pool.
        case dedicated
    }
}

// ============================================================
// MARK: - File.IO.Configuration.swift
// ============================================================

//
//  File.IO.Configuration.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Dispatch

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    public import WinSDK
#endif

extension File.IO {
    /// Configuration for the I/O executor.
    public struct Configuration: Sendable {
        /// Number of concurrent workers.
        public var workers: Int

        /// Maximum number of jobs in the queue.
        public var queueLimit: Int

        /// Thread model for worker execution.
        ///
        /// - `.cooperative`: Uses `Task.detached` (default, backward compatible)
        /// - `.dedicated`: Uses dedicated `DispatchQueue` instances
        public var threadModel: ThreadModel

        /// Default number of workers based on system resources.
        public static var defaultWorkerCount: Int {
            #if canImport(Darwin)
                return Int(sysconf(_SC_NPROCESSORS_ONLN))
            #elseif canImport(Glibc)
                return Int(sysconf(Int32(_SC_NPROCESSORS_ONLN)))
            #elseif os(Windows)
                return Int(GetActiveProcessorCount(WORD(ALL_PROCESSOR_GROUPS)))
            #else
                return 4  // Fallback for unknown platforms
            #endif
        }

        /// Creates a configuration.
        ///
        /// - Parameters:
        ///   - workers: Number of concurrent workers (default: active processor count).
        ///   - queueLimit: Maximum queue size (default: 10,000).
        ///   - threadModel: Thread model for execution (default: `.cooperative`).
        public init(
            workers: Int? = nil,
            queueLimit: Int = 10_000,
            threadModel: ThreadModel = .cooperative
        ) {
            self.workers = max(1, workers ?? Self.defaultWorkerCount)
            self.queueLimit = max(1, queueLimit)
            self.threadModel = threadModel
        }

        /// Default configuration for the shared executor.
        ///
        /// Conservative settings designed for the common case:
        /// - Workers: half of available cores (minimum 2)
        /// - Queue limit: 256 (bounded but reasonable)
        /// - Thread model: cooperative (non-blocking for most I/O)
        public static let `default` = Self(
            workers: max(2, defaultWorkerCount / 2),
            queueLimit: 256,
            threadModel: .cooperative
        )
    }
}

// ============================================================
// MARK: - File.IO.Executor.Error.swift
// ============================================================

//
//  File.IO.Executor.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// Errors specific to the executor.
    public enum ExecutorError: Error, Sendable {
        /// The executor has been shut down.
        case shutdownInProgress
    }
}

// ============================================================
// MARK: - File.IO.Executor.Job.swift
// ============================================================

//
//  File.IO.Executor.Job.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Type-erased job that encapsulates work and continuation.
protocol _Job: Sendable {
    func run()
    func fail(with error: any Error)
}

/// Typed job box that preserves static typing through execution.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Single-owner semantics with idempotent completion.
///
/// ### Proof:
/// 1. `isCompleted` guard prevents double-resume
/// 2. Each job is dequeued by exactly one worker thread
/// 3. `run()` and `fail()` are idempotent - second call is no-op
final class _JobBox<T: Sendable>: @unchecked Sendable, _Job {
    let operation: @Sendable () throws -> T
    private let continuation: CheckedContinuation<T, any Error>
    private var isCompleted = false  // Single-owner guard

    init(
        operation: @Sendable @escaping () throws -> T,
        continuation: CheckedContinuation<T, any Error>
    ) {
        self.operation = operation
        self.continuation = continuation
    }

    func run() {
        guard !isCompleted else { return }  // Idempotent
        isCompleted = true
        continuation.resume(with: Result { try operation() })
    }

    func fail(with error: any Error) {
        guard !isCompleted else { return }  // Idempotent
        isCompleted = true
        continuation.resume(throwing: error)
    }
}

// ============================================================
// MARK: - File.IO.Executor.RingBuffer.swift
// ============================================================

//
//  File.IO.Executor.RingBuffer.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// O(1) enqueue/dequeue queue using circular buffer.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Only accessed from actor-isolated context.
///
/// ### Proof:
/// 1. All mutations occur within `Executor` actor methods
/// 2. Actor isolation guarantees serial access
/// 3. The struct itself has no internal synchronization needs
struct _RingBuffer<T>: @unchecked Sendable {
    private var storage: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private var _count: Int = 0

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    init(capacity: Int) {
        storage = [T?](repeating: nil, count: max(capacity, 16))
    }

    mutating func enqueue(_ element: T) {
        if _count == storage.count {
            grow()
        }
        storage[tail] = element
        tail = (tail + 1) % storage.count
        _count += 1
    }

    mutating func dequeue() -> T? {
        guard _count > 0 else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % storage.count
        _count -= 1
        return element
    }

    /// Drain all elements.
    mutating func drainAll() -> [T] {
        var result: [T] = []
        result.reserveCapacity(_count)
        while let element = dequeue() {
            result.append(element)
        }
        return result
    }

    private mutating func grow() {
        var newStorage = [T?](repeating: nil, count: storage.count * 2)
        for i in 0..<_count {
            newStorage[i] = storage[(head + i) % storage.count]
        }
        head = 0
        tail = _count
        storage = newStorage
    }
}

// ============================================================
// MARK: - File.IO.Executor.WaiterState.swift
// ============================================================

//
//  File.IO.Executor.WaiterState.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

/// Token for cancellation-safe waiter tracking with single-owner semantics.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Thread-safe state transitions protected by Mutex.
///
/// ### Proof:
/// 1. All access to `state` occurs inside `lock.withLock`
/// 2. State transitions are atomic (check + update + resume in single critical section)
/// 3. Each continuation is resumed exactly once (state machine prevents double-resume)
final class _WaiterState: @unchecked Sendable {
    enum State {
        case waiting(CheckedContinuation<Void, Never>)
        case resumed
        case cancelled
    }

    private let lock: Mutex<State>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.lock = Mutex(.waiting(continuation))
    }

    /// Resume the waiter if still waiting. Returns true if resumed.
    func resume() -> Bool {
        lock.withLock { state in
            guard case .waiting(let continuation) = state else { return false }
            state = .resumed
            continuation.resume()
            return true
        }
    }

    /// Mark as cancelled and resume if still waiting.
    @discardableResult
    func cancel() -> Bool {
        lock.withLock { state in
            guard case .waiting(let continuation) = state else { return false }
            state = .cancelled
            continuation.resume()
            return true
        }
    }
}

/// Sendable box to capture waiter state across isolation boundaries.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Write-once semantics with happens-before relationship.
///
/// ### Proof:
/// 1. `state` is set exactly once in `withCheckedContinuation` body
/// 2. Read occurs in cancellation handler which runs after body completes
/// 3. Swift's continuation machinery establishes happens-before
final class _WaiterBox: @unchecked Sendable {
    var state: _WaiterState?
}

/// Sendable box to track cancellation state across isolation boundaries.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Single-writer (cancellation handler), read after synchronization.
///
/// ### Proof:
/// 1. Only written by cancellation handler (single writer)
/// 2. Read occurs after continuation resumes (happens-before via continuation)
/// 3. Value indicates whether cancel() was called, not precise timing
final class _CancellationBox: @unchecked Sendable {
    var value: Bool = false
}

// ============================================================
// MARK: - File.IO.Executor.swift
// ============================================================

//
//  File.IO.Executor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Dispatch

extension File.IO {
    /// A bounded pool for blocking I/O with configurable thread model.
    ///
    /// ## Thread Model
    /// The executor supports two thread models (configured via `Configuration.threadModel`):
    ///
    /// ### Cooperative (default)
    /// Uses Swift's cooperative thread pool via `Task.detached`. This means:
    /// - Blocking syscalls consume cooperative threads
    /// - Under sustained load, this can starve unrelated async work
    /// - `workers` bounds concurrency but does not provide dedicated threads
    ///
    /// ### Dedicated
    /// Uses dedicated `DispatchQueue` instances with explicit QoS:
    /// - Each worker has its own dispatch queue (user-initiated QoS)
    /// - Blocking I/O does not interfere with Swift's cooperative pool
    /// - Better isolation under sustained blocking operations
    ///
    /// ## Lifecycle
    /// - Lazy start: workers spawn on first `run()` call
    /// - **Fail-pending shutdown**: queued jobs fail with `.shutdownInProgress`
    /// - **The `.default` executor does not require shutdown** (process-scoped)
    ///
    /// ## Backpressure
    /// - Queue is bounded by `queueLimit` (ring buffer, O(1))
    /// - Callers suspend if queue is full
    /// - Cancellation while waiting removes the enqueue request
    ///
    /// ## Completion Guarantees
    /// - **Jobs run to completion once enqueued**
    /// - If caller is cancelled after enqueue, they receive `CancellationError`
    ///   (but the job still completes in the background)
    /// - `run()` after `shutdown()` throws `.shutdownInProgress`
    ///
    /// ## Handle Store
    /// The executor owns a handle store for managing stateful file handles.
    /// Use `registerHandle`, `withHandle`, and `destroyHandle` for handle operations.
    public actor Executor {
        private let configuration: Configuration
        private var queue: _RingBuffer<any _Job>
        private var capacityWaiters: [ObjectIdentifier: _WaiterState] = [:]
        private var isStarted: Bool = false
        private var isShutdown: Bool = false
        private var inFlightCount: Int = 0
        private var workerTasks: [Task<Void, Never>] = []
        private var shutdownContinuation: CheckedContinuation<Void, Never>?

        // Signal stream for workers (not polling)
        private var jobSignal: AsyncStream<Void>.Continuation?
        private var jobStream: AsyncStream<Void>?

        // Dedicated dispatch queues (only used in .dedicated thread model)
        private var dispatchQueues: [DispatchQueue] = []

        // Handle store for stateful file handle management
        private let handleStore: HandleStore

        // Whether this is the shared default executor (does not require shutdown)
        private let isDefaultExecutor: Bool

        // MARK: - Shared Default Executor

        /// The shared default executor for common use cases.
        ///
        /// This executor is lazily initialized and process-scoped:
        /// - Uses conservative default configuration
        /// - Does **not** require `shutdown()` (calling it is a no-op)
        /// - Suitable for the 80% case where you need simple async I/O
        ///
        /// For advanced use cases (dedicated threads, custom configuration,
        /// explicit lifecycle management), create your own executor instance.
        ///
        /// ## Example
        /// ```swift
        /// for try await entry in File.Directory.Async(io: .default).entries(at: path) {
        ///     print(entry.name)
        /// }
        /// ```
        public static let `default` = Executor(default: .default)

        // MARK: - Initializers

        /// Creates an executor with the given configuration.
        ///
        /// Executors created with this initializer **must** be shut down
        /// when no longer needed using `shutdown()`.
        public init(_ configuration: Configuration = .init()) {
            self.configuration = configuration
            self.queue = _RingBuffer(capacity: min(configuration.queueLimit, 1024))
            self.handleStore = HandleStore()
            self.isDefaultExecutor = false
        }

        /// Private initializer for the default executor.
        private init(default configuration: Configuration) {
            self.configuration = configuration
            self.queue = _RingBuffer(capacity: min(configuration.queueLimit, 1024))
            self.handleStore = HandleStore()
            self.isDefaultExecutor = true
        }

        /// Execute a blocking operation on a worker thread.
        ///
        /// ## Cancellation Semantics
        /// - Cancellation while waiting for queue capacity → `CancellationError`
        /// - Cancellation after enqueue → **job still runs** (mutation occurs),
        ///   but caller receives `CancellationError` instead of result
        ///
        /// - Throws: `ExecutorError.shutdownInProgress` if executor is shut down
        /// - Throws: `CancellationError` if task is cancelled
        public func run<T: Sendable>(
            _ operation: @Sendable @escaping () throws -> T
        ) async throws -> T {
            // Check cancellation upfront
            try Task.checkCancellation()

            // Reject if shutdown
            guard !isShutdown else {
                throw ExecutorError.shutdownInProgress
            }

            // Lazy start workers on first call
            if !isStarted {
                startWorkers()
                isStarted = true
            }

            // Wait for queue space if full (cancellation-safe, single-owner)
            while queue.count >= configuration.queueLimit {
                let waiterBox = _WaiterBox()

                await withTaskCancellationHandler {
                    await withCheckedContinuation {
                        (continuation: CheckedContinuation<Void, Never>) in
                        let waiterState = _WaiterState(continuation)
                        waiterBox.state = waiterState
                        capacityWaiters[ObjectIdentifier(waiterState)] = waiterState
                    }
                } onCancel: {
                    // Single-owner: cancel() returns false if already resumed
                    waiterBox.state?.cancel()
                }

                // Remove from dict (idempotent)
                if let state = waiterBox.state {
                    capacityWaiters.removeValue(forKey: ObjectIdentifier(state))
                }

                try Task.checkCancellation()

                // Re-check shutdown after waking
                guard !isShutdown else {
                    throw ExecutorError.shutdownInProgress
                }
            }

            // Track whether caller was cancelled during execution
            let wasCancelled = _CancellationBox()

            // Enqueue and wait for result
            // Note: Once enqueued, job completes regardless of caller cancellation
            let result = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<T, any Error>) in
                    let job = _JobBox(operation: operation, continuation: continuation)
                    queue.enqueue(job)
                    // Signal workers that a job is available
                    jobSignal?.yield()
                }
            } onCancel: {
                wasCancelled.value = true
            }

            // If caller was cancelled while job was running, throw CancellationError
            // (even though the job completed successfully)
            if wasCancelled.value {
                throw CancellationError()
            }

            return result
        }

        /// Fail-pending shutdown.
        ///
        /// 1. Set `isShutdown = true` (rejects new `run()` calls)
        /// 2. **Fail all queued jobs** with `.shutdownInProgress`
        /// 3. Resume all capacity waiters
        /// 4. Wait for in-flight jobs to complete
        /// 5. **Close all remaining handles** (best-effort, errors logged)
        /// 6. End workers
        ///
        /// - Note: Calling `shutdown()` on the `.default` executor is a no-op.
        ///   The default executor is process-scoped and does not require shutdown.
        public func shutdown() async {
            // Default executor is process-scoped - shutdown is a no-op
            guard !isDefaultExecutor else { return }

            guard !isShutdown else { return }  // Idempotent
            isShutdown = true

            // 1. Fail all queued jobs atomically
            let pendingJobs = queue.drainAll()
            for job in pendingJobs {
                job.fail(with: ExecutorError.shutdownInProgress)
            }

            // 2. Resume all capacity waiters (single-owner: skip if already cancelled)
            for (_, waiterState) in capacityWaiters {
                _ = waiterState.resume()
            }
            capacityWaiters.removeAll()

            // 3. Wait for in-flight jobs to complete
            if inFlightCount > 0 {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    shutdownContinuation = continuation
                }
            }

            // 4. Close all remaining handles (after in-flight jobs complete)
            handleStore.shutdown()

            // 5. End workers
            jobSignal?.finish()
            for task in workerTasks {
                task.cancel()
            }
            for task in workerTasks {
                _ = await task.result
            }
            workerTasks.removeAll()
        }

        // MARK: - Handle Management

        /// Register a file handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: A unique handle ID for future operations.
        /// - Throws: `ExecutorError.shutdownInProgress` if executor is shut down.
        public nonisolated func registerHandle(_ handle: consuming File.Handle) throws -> HandleID {
            try handleStore.register(handle)
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// The closure runs inside an `io.run` context, ensuring proper I/O scheduling.
        /// The handle is accessed via inout for in-place mutation.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different executor.
        /// - Throws: `HandleError.invalidHandleID` if handle was already destroyed.
        /// - Throws: Any error from the closure.
        public func withHandle<T: Sendable>(
            _ id: HandleID,
            _ body: @Sendable @escaping (inout File.Handle) throws -> T
        ) async throws -> T {
            try await run {
                try self.handleStore.withHandle(id, body)
            }
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different executor.
        /// - Throws: Close errors from the underlying handle.
        /// - Note: Idempotent for handles that were already destroyed.
        public func destroyHandle(_ id: HandleID) async throws {
            try await run {
                try self.handleStore.destroy(id)
            }
        }

        /// Check if a handle ID is currently valid.
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle exists and is open.
        public nonisolated func isHandleValid(_ id: HandleID) -> Bool {
            handleStore.isValid(id)
        }

        // MARK: - Private

        private func startWorkers() {
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            self.jobStream = stream
            self.jobSignal = continuation

            switch configuration.threadModel {
            case .cooperative:
                // Current implementation: Task.detached uses cooperative thread pool
                for _ in 0..<configuration.workers {
                    let task = Task.detached { [weak self] in
                        guard let self else { return }
                        await self.workerLoop()
                    }
                    workerTasks.append(task)
                }

            case .dedicated:
                // Dedicated dispatch queues with explicit QoS
                for i in 0..<configuration.workers {
                    let queue = DispatchQueue(
                        label: "file.io.worker.\(i)",
                        qos: .userInitiated
                    )
                    dispatchQueues.append(queue)

                    let task = Task.detached { [weak self] in
                        guard let self else { return }
                        await self.dedicatedWorkerLoop(queue: queue)
                    }
                    workerTasks.append(task)
                }
            }
        }

        private func workerLoop() async {
            guard let stream = jobStream else { return }

            for await _ in stream {
                while !Task.isCancelled {
                    guard let job = dequeueJob() else { break }

                    // Execute OUTSIDE actor isolation
                    await executeJob(job)

                    // Track completion for shutdown
                    jobCompleted()
                }
            }
        }

        private func dedicatedWorkerLoop(queue: DispatchQueue) async {
            guard let stream = jobStream else { return }

            for await _ in stream {
                while !Task.isCancelled {
                    guard let job = dequeueJob() else { break }

                    // Execute on dedicated dispatch queue
                    await withCheckedContinuation {
                        (continuation: CheckedContinuation<Void, Never>) in
                        queue.async {
                            job.run()
                            continuation.resume()
                        }
                    }

                    // Track completion for shutdown
                    jobCompleted()
                }
            }
        }

        private func dequeueJob() -> (any _Job)? {
            guard let job = queue.dequeue() else { return nil }

            inFlightCount += 1

            // Signal ONE capacity waiter (single-owner via state)
            if let (id, waiterState) = capacityWaiters.first {
                if waiterState.resume() {
                    capacityWaiters.removeValue(forKey: id)
                }
            }
            return job
        }

        private func jobCompleted() {
            inFlightCount -= 1
            // If shutdown is waiting for in-flight to drain
            if isShutdown && inFlightCount == 0 {
                shutdownContinuation?.resume()
                shutdownContinuation = nil
            }
        }

        /// Execute job outside actor isolation.
        private nonisolated func executeJob(_ job: any _Job) async {
            job.run()
        }
    }
}

// ============================================================
// MARK: - File.IO.HandleBox.swift
// ============================================================

//
//  File.IO.HandleBox.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO {
    /// A heap-allocated box that owns a File.Handle with its own lock.
    ///
    /// This design enables:
    /// - Per-handle locking (parallelism across different handles)
    /// - Stable storage address (dictionary rehashing doesn't invalidate inout)
    /// - Safe concurrent access patterns
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - All access to `storage` occurs within `state.withLock { }`.
    /// - The `UnsafeMutablePointer` provides a stable address for inout access
    ///   to the ~Copyable File.Handle.
    /// - No closure passed to withLock is async or escaping.
    final class HandleBox: @unchecked Sendable {
        /// State protecting the handle storage.
        /// - `true`: handle is open (storage is valid)
        /// - `false`: handle is closed (storage is nil)
        private let state: Mutex<Bool>

        /// Pointer to the handle storage. Only accessed under state lock.
        /// Nil means closed.
        private var storage: UnsafeMutablePointer<File.Handle>?

        /// The path (for diagnostics).
        let path: File.Path
        /// The mode (for diagnostics).
        let mode: File.Handle.Mode

        init(_ handle: consuming File.Handle) {
            self.path = handle.path
            self.mode = handle.mode
            // Allocate and initialize storage
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume handle)
            self.state = Mutex(true)
        }

        deinit {
            // If storage still exists, we need to clean up.
            // Note: Close errors are intentionally discarded in deinit
            // (deinit is leak prevention only).
            if let ptr = storage {
                let handle = ptr.move()
                ptr.deallocate()
                _ = try? handle.close()
            }
        }

        /// Whether the handle is still open.
        var isOpen: Bool {
            state.withLock { $0 }
        }

        /// Execute a closure with exclusive access to the handle.
        ///
        /// - Parameter body: Closure receiving inout access to the handle.
        ///   Must be synchronous and non-escaping.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.handleClosed` if handle was already closed.
        func withHandle<T>(_ body: (inout File.Handle) throws -> T) throws -> T {
            try state.withLock { isOpen in
                guard isOpen, let ptr = storage else {
                    throw HandleError.handleClosed
                }
                // Access via pointer - stable address, no move required
                return try body(&ptr.pointee)
            }
        }

        /// Close the handle and return any error.
        ///
        /// - Returns: The close error, if any.
        /// - Note: Idempotent - second call returns nil.
        func close() -> (any Error)? {
            // First, atomically mark as closed and get storage
            let ptr: UnsafeMutablePointer<File.Handle>? = state.withLock { isOpen in
                guard isOpen, let ptr = storage else {
                    return nil  // Already closed
                }
                isOpen = false
                storage = nil
                return ptr
            }

            // If already closed, return nil
            guard let ptr else {
                return nil
            }

            // Move out, deallocate, close (outside lock)
            let handle = ptr.move()
            ptr.deallocate()

            do {
                try handle.close()
                return nil
            } catch {
                return error
            }
        }
    }
}

// ============================================================
// MARK: - File.IO.HandleError.swift
// ============================================================

//
//  File.IO.HandleError.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// Errors related to handle operations in the store.
    public enum HandleError: Error, Sendable {
        /// The handle ID does not exist in the store (already closed or never existed).
        case invalidHandleID
        /// The handle ID belongs to a different executor/store.
        case scopeMismatch
        /// The handle has already been closed.
        case handleClosed
    }
}

// ============================================================
// MARK: - File.IO.HandleID.swift
// ============================================================

//
//  File.IO.HandleID.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// A unique identifier for a registered file handle.
    ///
    /// HandleIDs are:
    /// - Scoped to a specific executor/store instance (prevents cross-executor misuse)
    /// - Never reused within an executor's lifetime
    /// - Sendable and Hashable for use as dictionary keys
    public struct HandleID: Hashable, Sendable {
        /// The unique identifier within the store.
        let raw: UInt64
        /// The scope identifier (unique per store instance).
        let scope: UInt64
    }
}

// ============================================================
// MARK: - File.IO.HandleStore.State.swift
// ============================================================

//
//  File.IO.HandleStore.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// Internal state protected by the store's mutex.
    struct HandleStoreState: ~Copyable {
        /// The handle storage.
        var handles: [HandleID: HandleBox] = [:]
        /// Counter for generating unique IDs.
        var nextID: UInt64 = 0
        /// Whether the store has been shut down.
        var isShutdown: Bool = false
    }
}

// ============================================================
// MARK: - File.IO.HandleStore.swift
// ============================================================

//
//  File.IO.HandleStore.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO {
    /// Thread-safe storage for file handles, owned by an executor.
    ///
    /// ## Design
    /// - Dictionary maps HandleID → HandleBox
    /// - Store mutex guards map mutations and shutdown state
    /// - Per-handle locks (in HandleBox) guard handle operations
    /// - This enables parallelism across different handles
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - All mutation of `state` contents occurs inside `state.withLock { }`.
    /// - Boxes are never returned to users; only accessed inside io.run jobs.
    /// - No closure passed to withLock is async or escaping.
    ///
    /// ## Lifecycle
    /// - Store lifetime = Executor lifetime
    /// - Shutdown forcibly closes remaining handles
    final class HandleStore: @unchecked Sendable {
        /// Protected state containing dictionary and metadata.
        private let state: Mutex<HandleStoreState>

        /// Unique scope identifier for this store instance.
        let scope: UInt64

        /// Global counter for generating unique scope IDs.
        private static let scopeCounter = _AtomicCounter()

        init() {
            // Generate a unique scope ID for this store instance
            self.scope = Self.scopeCounter.next()
            self.state = Mutex(HandleStoreState())
        }

        /// Register a handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: The handle ID for future operations.
        /// - Throws: `ExecutorError.shutdownInProgress` if store is shut down.
        ///
        /// ## Implementation Note
        /// The handle is consumed outside the lock because `Mutex.withLock` takes
        /// an escaping closure, and noncopyable types cannot be consumed inside
        /// escaping closures. We use a two-phase approach:
        /// 1. Quick check if shutdown in progress (return early if so)
        /// 2. Create HandleBox (consumes handle)
        /// 3. Atomically register under lock (with double-check for shutdown race)
        ///
        /// If shutdown races between phase 1 and 3, the HandleBox's deinit will
        /// close the handle as a safety net.
        func register(_ handle: consuming File.Handle) throws -> HandleID {
            let scope = self.scope

            // Phase 1: Quick shutdown check (avoid creating box if already shutdown)
            let alreadyShutdown = state.withLock { $0.isShutdown }
            if alreadyShutdown {
                _ = try? handle.close()
                throw ExecutorError.shutdownInProgress
            }

            // Phase 2: Create box (consumes handle) - outside lock
            let box = HandleBox(handle)

            // Phase 3: Atomically register (with double-check)
            return try state.withLock { state in
                guard !state.isShutdown else {
                    // Race: shutdown started after our check
                    // box.deinit will close the handle
                    throw ExecutorError.shutdownInProgress
                }

                let id = HandleID(raw: state.nextID, scope: scope)
                state.nextID += 1
                state.handles[id] = box
                return id
            }
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: `HandleError.invalidHandleID` if ID not found.
        /// - Throws: `HandleError.handleClosed` if handle was closed.
        func withHandle<T>(_ id: HandleID, _ body: (inout File.Handle) throws -> T) throws -> T {
            // Validate scope first
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Find the box (short lock on dictionary)
            let box: HandleBox? = state.withLock { state in
                state.handles[id]
            }

            guard let box else {
                throw HandleError.invalidHandleID
            }

            // Execute with per-handle lock (box has its own Mutex)
            return try box.withHandle(body)
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: Close errors from the underlying handle.
        /// - Note: Idempotent for same-scope IDs that were already closed.
        func destroy(_ id: HandleID) throws {
            // Validate scope first - scope mismatch is always an error
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Remove from dictionary (short lock)
            let box: HandleBox? = state.withLock { state in
                state.handles.removeValue(forKey: id)
            }

            // If not found, treat as already closed (idempotent)
            guard let box else {
                return
            }

            // Close the handle (may throw)
            if let error = box.close() {
                throw error
            }
        }

        /// Shutdown the store: close all remaining handles.
        ///
        /// - Note: Close errors are logged but not propagated.
        /// - Postcondition: All handles closed, store rejects new registrations.
        func shutdown() {
            // Atomically mark shutdown and extract remaining handles
            let remainingHandles: [HandleID: HandleBox] = state.withLock { state in
                state.isShutdown = true
                let handles = state.handles
                state.handles.removeAll()
                return handles
            }

            // Close all remaining handles (best-effort, outside lock)
            for (id, box) in remainingHandles {
                if let error = box.close() {
                    #if DEBUG
                        print("Warning: Error closing handle \(id.raw) during shutdown: \(error)")
                    #endif
                }
            }
        }

        /// Check if a handle ID is valid (for diagnostics).
        func isValid(_ id: HandleID) -> Bool {
            guard id.scope == scope else { return false }
            return state.withLock { state in
                state.handles[id] != nil
            }
        }

        /// The number of registered handles (for testing).
        var count: Int {
            state.withLock { state in
                state.handles.count
            }
        }
    }
}

// ============================================================
// MARK: - File.IO.swift
// ============================================================

//
//  File.IO.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File {
    /// Namespace for I/O coordination.
    ///
    /// Contains the `Executor` for running blocking I/O operations
    /// on a bounded cooperative pool.
    public enum IO {}
}

// ============================================================
// MARK: - File.Stream.Async.Byte.Sequence.Iterator.Async.swift
// ============================================================

//
//  File.Stream.Async.Byte.Sequence.Iterator.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import AsyncAlgorithms

extension File.Stream.Async.ByteSequence {
    /// The async iterator for byte streaming.
    public final class AsyncIterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncThrowingChannel<Element, any Error>
        private var channelIterator: AsyncThrowingChannel<Element, any Error>.AsyncIterator
        private let producerTask: Task<Void, Never>
        private var isFinished = false

        init(path: File.Path, chunkSize: Int, io: File.IO.Executor) {
            let channel = AsyncThrowingChannel<Element, any Error>()
            self.channel = channel
            self.channelIterator = channel.makeAsyncIterator()

            self.producerTask = Task {
                await Self.runProducer(
                    path: path,
                    chunkSize: chunkSize,
                    io: io,
                    channel: channel
                )
            }
        }

        deinit {
            producerTask.cancel()
        }

        public func next() async throws -> Element? {
            guard !isFinished else { return nil }

            do {
                try Task.checkCancellation()
                let result = try await channelIterator.next()
                if result == nil {
                    isFinished = true
                }
                return result
            } catch {
                isFinished = true
                producerTask.cancel()
                throw error
            }
        }

        /// Explicitly terminate streaming.
        public func terminate() {
            guard !isFinished else { return }
            isFinished = true
            producerTask.cancel()
            channel.finish()  // Consumer's next() returns nil immediately
        }

        // MARK: - Producer

        private static func runProducer(
            path: File.Path,
            chunkSize: Int,
            io: File.IO.Executor,
            channel: AsyncThrowingChannel<Element, any Error>
        ) async {
            // Open file
            let handleResult: Result<File.IO.HandleID, any Error> = await {
                do {
                    let id = try await io.run {
                        let handle = try File.Handle.open(path, mode: .read)
                        return try io.registerHandle(handle)
                    }
                    return .success(id)
                } catch {
                    return .failure(error)
                }
            }()

            guard case .success(let handleId) = handleResult else {
                if case .failure(let error) = handleResult {
                    channel.fail(error)
                }
                return
            }

            // Stream chunks
            do {
                while true {
                    try Task.checkCancellation()

                    // Read chunk - allocate inside closure for Sendable safety
                    let chunk: [UInt8] = try await io.withHandle(handleId) { handle in
                        try handle.read(count: chunkSize)
                    }

                    // EOF
                    if chunk.isEmpty {
                        break
                    }

                    try Task.checkCancellation()

                    // Yield owned chunk
                    await channel.send(chunk)
                }

                // Clean close
                try? await io.destroyHandle(handleId)
                channel.finish()

            } catch is CancellationError {
                // Cancelled - clean up
                try? await io.destroyHandle(handleId)
                channel.finish()

            } catch {
                // Error - clean up and propagate
                try? await io.destroyHandle(handleId)
                channel.fail(error)
            }
        }
    }
}

// ============================================================
// MARK: - File.Stream.Async.Byte.Sequence.swift
// ============================================================

//
//  File.Stream.Async.Byte.Sequence.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
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
        options: BytesOptions = BytesOptions()
    ) -> ByteSequence {
        ByteSequence(path: path, chunkSize: options.chunkSize, io: io)
    }
}

// MARK: - ByteSequence

extension File.Stream.Async {
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
    public struct ByteSequence: AsyncSequence, Sendable {
        public typealias Element = [UInt8]

        let path: File.Path
        let chunkSize: Int
        let io: File.IO.Executor

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(path: path, chunkSize: chunkSize, io: io)
        }
    }
}

// ============================================================
// MARK: - File.Stream.Async.Bytes.Options.swift
// ============================================================

//
//  File.Stream.Async.Bytes.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Stream.Async {
    /// Options for byte streaming.
    public struct BytesOptions: Sendable {
        /// Size of each chunk in bytes.
        public var chunkSize: Int

        /// Creates byte streaming options.
        ///
        /// - Parameter chunkSize: Chunk size in bytes (default: 64KB).
        public init(chunkSize: Int = 64 * 1024) {
            self.chunkSize = max(1, chunkSize)
        }
    }
}

// ============================================================
// MARK: - File.Stream.Async.swift
// ============================================================

//
//  File.Stream.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File {
    /// Namespace for streaming file APIs.
    public enum Stream {}
}

extension File.Stream {
    /// Internal async streaming implementation.
    ///
    /// Use the static methods instead:
    /// ```swift
    /// for try await chunk in File.Stream.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async stream API with the given executor.
        init(io: File.IO.Executor = .default) {
            self.io = io
        }
    }

    // MARK: - Static Convenience Methods

    /// Stream file bytes asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await chunk in File.Stream.bytes(from: path) {
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
        options: Async.BytesOptions = .init(),
        io: File.IO.Executor = .default
    ) -> Async.ByteSequence {
        Async(io: io).bytes(from: path, options: options)
    }
}

// ============================================================
// MARK: - File.System+Async.swift
// ============================================================

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
            return metadata.type == .regular
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
            return metadata.type == .directory
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

// ============================================================
// MARK: - exports.swift
// ============================================================

//
//  exports.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

@_exported public import AsyncAlgorithms
// Re-export primitives for consumers of the async layer
@_exported import File_System_Primitives
