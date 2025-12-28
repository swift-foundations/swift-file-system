//
//  File.Directory.Walk.Async.Sequence.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import AsyncAlgorithms
import Synchronization

extension File.Directory.Walk.Async.Sequence {
    /// The async iterator for directory walk.
    ///
    /// ## Thread Safety
    /// This iterator is task-confined. Do not share across Tasks.
    /// The non-Sendable conformance enforces this at compile time.
    public final class Iterator: AsyncIteratorProtocol {
        private typealias Box = File.Iterator.Box<File.Directory.Iterator>
        private typealias ChannelError = IO.Lifecycle.Error<IO.Error<File.Directory.Walk.Error>>

        private let channel: AsyncThrowingChannel<Element, ChannelError>
        private var channelIterator: AsyncThrowingChannel<Element, ChannelError>.AsyncIterator
        private var producerTask: Task<Void, Never>?
        private let _isFinished = Atomic<Bool>(false)

        private init(
            channel: AsyncThrowingChannel<Element, ChannelError>,
            channelIterator: AsyncThrowingChannel<Element, ChannelError>.AsyncIterator
        ) {
            self.channel = channel
            self.channelIterator = channelIterator
        }

        /// Factory method to create iterator and start producer.
        /// Uses factory pattern to avoid init-region isolation issues.
        static func make(
            root: File.Directory,
            options: File.Directory.Walk.Async.Options,
            fs: File.System.Async
        ) -> Iterator {
            let channel = AsyncThrowingChannel<Element, ChannelError>()
            let iterator = Iterator(
                channel: channel,
                channelIterator: channel.makeAsyncIterator()
            )

            // Capture only Sendable values, not self
            let root = root
            let options = options
            let fs = fs
            iterator.producerTask = Task {
                await Self.runWalk(root: root, options: options, fs: fs, channel: channel)
            }

            return iterator
        }

        deinit {
            producerTask?.cancel()
        }

        public func next() async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Walk.Error>>) -> Element? {
            guard !_isFinished.load(ordering: .acquiring) else { return nil }

            // Check cancellation without throwing (avoids mixing throw types)
            if Task.isCancelled {
                _isFinished.store(true, ordering: .releasing)
                producerTask?.cancel()
                throw .failure(.cancelled)
            }

            // Pure typed throws from channel - no cast needed
            do {
                let result = try await channelIterator.next()

                // TERMINATION BARRIER:
                // If terminate() raced while we were suspended, discard any buffered element.
                // This ensures "terminate stops iteration" is honored even if elements were queued.
                if _isFinished.load(ordering: .acquiring) { return nil }

                if result == nil {
                    _isFinished.store(true, ordering: .releasing)
                }
                return result
            } catch {
                _isFinished.store(true, ordering: .releasing)
                producerTask?.cancel()
                throw error
            }
        }

        /// Explicitly terminate the walk and wait for cleanup to complete.
        ///
        /// This is a barrier: after `await terminate()` returns, all resources
        /// have been released. Safe to call `io.shutdown()` afterward.
        public func terminate() async {
            // Atomically check and set finished flag
            let (exchanged, _) = _isFinished.compareExchange(
                expected: false,
                desired: true,
                ordering: .acquiringAndReleasing
            )
            guard exchanged else { return }

            producerTask?.cancel()
            channel.finish()  // Signals channel completion
            _ = await producerTask?.value  // Barrier: wait for producer cleanup
        }

        // MARK: - Walk Implementation

        private static func runWalk(
            root: File.Directory,
            options: File.Directory.Walk.Async.Options,
            fs: File.System.Async,
            channel: AsyncThrowingChannel<Element, ChannelError>
        ) async {
            let state = File.Directory.Walk.Async.State(maxConcurrency: options.maxConcurrency)
            let authority = File.Directory.Walk.Async.Completion.Authority()

            // Enqueue root
            await state.enqueue(root, depth: 0)

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
                    guard let (dir, depth) = await state.dequeue() else {
                        // No dirs in queue - wait for active workers
                        await state.waitForWorkOrCompletion()
                        continue
                    }

                    // Check depth limit
                    if let maxDepth = options.maxDepth, depth > maxDepth {
                        await state.decrementActive()
                        continue
                    }

                    // Acquire semaphore slot
                    await state.acquireSemaphore()

                    // Spawn worker task
                    group.addTask {
                        await Self.processDirectory(
                            dir,
                            depth: depth,
                            options: options,
                            fs: fs,
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
            _ dir: File.Directory,
            depth: Int,
            options: File.Directory.Walk.Async.Options,
            fs: File.System.Async,
            state: File.Directory.Walk.Async.State,
            authority: File.Directory.Walk.Async.Completion.Authority,
            channel: AsyncThrowingChannel<Element, ChannelError>
        ) async {
            // Check if already done
            guard await !authority.isComplete else {
                await state.decrementActive()  // Don't leak worker count
                return
            }

            // Mark this directory as visited for cycle detection.
            // This ensures that if a symlink points back to this directory,
            // we detect the cycle even for the root directory.
            if options.followSymlinks {
                if let dirInode = await getInode(dir.path, fs: fs, followSymlinks: true) {
                    let isNewVisit = await state.markVisited(dirInode)
                    if !isNewVisit {
                        // Already visited - this is a cycle, skip this directory
                        await state.decrementActive()
                        return
                    }
                }
            }

            // Open iterator
            let boxResult: Result<Box, ChannelError>
            do {
                let box = try await fs.run { () throws(File.Directory.Iterator.Error) in
                    let iterator = try File.Directory.Iterator.open(at: dir)
                    return Box(iterator)
                }
                boxResult = .success(box)
            } catch {
                // error is typed as IO.Lifecycle.Error<IO.Error<File.Directory.Iterator.Error>>
                // Map iterator error to walk error
                let walkError: ChannelError
                switch error {
                case .lifecycle(let lifecycle):
                    walkError = .lifecycle(lifecycle)
                case .failure(let ioError):
                    let mapped: IO.Error<File.Directory.Walk.Error> = ioError.mapOperation { iteratorError in
                        switch iteratorError {
                        case .pathNotFound(let p): return .pathNotFound(p)
                        case .permissionDenied(let p): return .permissionDenied(p)
                        case .notADirectory(let p): return .notADirectory(p)
                        case .readFailed(let errno, let msg):
                            return .walkFailed(errno: errno, message: msg)
                        }
                    }
                    walkError = .failure(mapped)
                }
                boxResult = .failure(walkError)
            }

            guard case .success(let box) = boxResult else {
                if case .failure(let error) = boxResult {
                    await authority.fail(with: error)
                }
                await state.decrementActive()
                return
            }

            // Helper to close box - must be called before returning
            @Sendable func closeBox() async {
                _ = try? await fs.run { box.close { $0.close() } }
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
                    let batch: [File.Directory.Entry] = try await fs.run {
                        () throws(File.Directory.Iterator.Error) in
                        var entries: [File.Directory.Entry] = []
                        entries.reserveCapacity(batchSize)
                        for _ in 0..<batchSize {
                            // withValue returns nil if box is closed, next() returns nil at EOF
                            guard
                                let maybeEntry = try box.withValue({
                                    (
                                        iter: inout File.Directory.Iterator
                                    ) throws(File.Directory.Iterator.Error) in
                                    try iter.next()
                                }),
                                let entry = maybeEntry
                            else { break }
                            entries.append(entry)
                        }
                        return entries
                    }

                    guard !batch.isEmpty else { break }

                    // Process batch entries
                    for entry in batch {
                        // Filter hidden files
                        if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                            continue
                        }

                        // Skip entries with undecodable names (no valid path)
                        guard let entryPath = entry.pathIfValid else {
                            // Invoke undecodable callback
                            let context = File.Directory.Walk.Undecodable.Context(
                                parent: entry.parent,
                                name: entry.name,
                                type: entry.type,
                                depth: depth
                            )
                            switch options.onUndecodable(context) {
                            case .skip:
                                continue
                            case .emit:
                                // Can't emit - no valid path
                                continue
                            case .stopAndThrow:
                                await authority.fail(
                                    with: .failure(
                                        .operation(
                                            .undecodableEntry(
                                                parent: entry.parent,
                                                name: entry.name
                                            )
                                        )
                                    )
                                )
                            }
                            continue
                        }

                        // Send path to consumer
                        await channel.send(entryPath)

                        // Check if we should recurse
                        let shouldRecurse: Bool
                        if entry.type == .directory {
                            shouldRecurse = true
                        } else if options.followSymlinks && entry.type == .symbolicLink {
                            // Get the TARGET's inode for cycle detection.
                            // We use followSymlinks: true to get the target's identity,
                            // so if this symlink points to an already-visited directory,
                            // we detect the cycle and don't recurse.
                            if let targetInode = await getInode(entryPath, fs: fs, followSymlinks: true) {
                                shouldRecurse = await state.markVisited(targetInode)
                            } else {
                                shouldRecurse = false
                            }
                        } else {
                            shouldRecurse = false
                        }

                        if shouldRecurse {
                            let subdir = File.Directory(entryPath)
                            await state.enqueue(subdir, depth: depth + 1)
                        }
                    }
                }
            } catch {
                let walkError: IO.Lifecycle.Error<IO.Error<File.Directory.Walk.Error>>
                switch error {
                case .lifecycle(let lifecycle):
                    walkError = .lifecycle(lifecycle)
                case .failure(let ioError):
                    let mapped: IO.Error<File.Directory.Walk.Error> = ioError.mapOperation { iteratorError in
                        switch iteratorError {
                        case .pathNotFound(let p): return .pathNotFound(p)
                        case .permissionDenied(let p): return .permissionDenied(p)
                        case .notADirectory(let p): return .notADirectory(p)
                        case .readFailed(let errno, let msg):
                            return .walkFailed(errno: errno, message: msg)
                        }
                    }
                    walkError = .failure(mapped)
                }
                await authority.fail(with: walkError)
            }

            // Close box synchronously before returning
            await closeBox()
            await state.decrementActive()
        }

        /// Gets the inode of a path for cycle detection.
        ///
        /// When detecting cycles for symlink following, we need the TARGET's inode
        /// (using stat which follows symlinks), not the symlink's own inode.
        /// This ensures that different symlinks pointing to the same directory
        /// are correctly detected as cycles.
        private static func getInode(
            _ path: File.Path,
            fs: File.System.Async,
            followSymlinks: Bool
        ) async -> File.Directory.Walk.Async.Inode.Key? {
            do {
                return try await fs.run {
                    // Use stat (follows symlinks) when we're about to follow a symlink
                    // to detect if the target has already been visited.
                    // Use lstat when we just need the entry's own inode.
                    let info =
                        followSymlinks
                        ? try File.System.Stat.info(at: path)
                        : try File.System.Stat.lstatInfo(at: path)
                    return File.Directory.Walk.Async.Inode.Key(
                        device: info.deviceId,
                        inode: info.inode
                    )
                }
            } catch {
                return nil
            }
        }
    }
}
