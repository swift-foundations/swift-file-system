//
//  File.Directory.Walk.Async.Sequence.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import AsyncAlgorithms

extension File.Directory.Walk.Async.Sequence {
    /// The async iterator for directory walk.
    ///
    /// ## Thread Safety
    /// This iterator is task-confined. Do not share across Tasks.
    /// The non-Sendable conformance enforces this at compile time.
    public final class Iterator: AsyncIteratorProtocol {
        private let channel: AsyncThrowingChannel<Element, any Error>
        private var channelIterator: AsyncThrowingChannel<Element, any Error>.AsyncIterator
        private var producerTask: Task<Void, Never>?
        private var isFinished = false

        private init(
            channel: AsyncThrowingChannel<Element, any Error>,
            channelIterator: AsyncThrowingChannel<Element, any Error>.AsyncIterator
        ) {
            self.channel = channel
            self.channelIterator = channelIterator
        }

        /// Factory method to create iterator and start producer.
        /// Uses factory pattern to avoid init-region isolation issues.
        static func make(
            root: File.Path,
            options: File.Directory.Walk.Async.Options,
            io: File.IO.Executor
        ) -> Iterator {
            let channel = AsyncThrowingChannel<Element, any Error>()
            let iterator = Iterator(
                channel: channel,
                channelIterator: channel.makeAsyncIterator()
            )

            // Capture only Sendable values, not self
            let root = root
            let options = options
            let io = io
            iterator.producerTask = Task {
                await Self.runWalk(root: root, options: options, io: io, channel: channel)
            }

            return iterator
        }

        deinit {
            producerTask?.cancel()
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
                producerTask?.cancel()
                throw error
            }
        }

        /// Explicitly terminate the walk and wait for cleanup to complete.
        ///
        /// This is a barrier: after `await terminate()` returns, all resources
        /// have been released. Safe to call `io.shutdown()` afterward.
        public func terminate() async {
            guard !isFinished else { return }
            isFinished = true
            producerTask?.cancel()
            channel.finish()  // Consumer's next() returns nil immediately
            _ = await producerTask?.value  // Barrier: wait for producer cleanup
        }

        // MARK: - Walk Implementation

        private static func runWalk(
            root: File.Path,
            options: File.Directory.Walk.Async.Options,
            io: File.IO.Executor,
            channel: AsyncThrowingChannel<Element, any Error>
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
            depth: Int,
            options: File.Directory.Walk.Async.Options,
            io: File.IO.Executor,
            state: File.Directory.Walk.Async.State,
            authority: File.Directory.Walk.Async.Completion.Authority,
            channel: AsyncThrowingChannel<Element, any Error>
        ) async {
            // Check if already done
            guard await !authority.isComplete else {
                await state.decrementActive()  // Don't leak worker count
                return
            }

            // Open iterator
            let boxResult: Result<Box, any Error> = await {
                do {
                    let box = try await io.run {
                        let iterator = try File.Directory.Iterator.open(at: dir)
                        return Box(iterator)
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

            // Helper to close box - must be called before returning
            // Two-tier invariant: io.run while operational, direct close on shutdown
            @Sendable func closeBox() async {
                do {
                    try await io.run { box.close() }
                } catch {
                    // Executor failed (shutdown) - close directly to prevent leaks
                    box.close()
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
                                await authority.fail(with: File.Directory.Walk.Error.undecodableEntry(
                                    parent: entry.parent,
                                    name: entry.name
                                ))
                                break
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
                            // Get inode for cycle detection
                            if let inode = await getInode(entryPath, io: io) {
                                shouldRecurse = await state.markVisited(inode)
                            } else {
                                shouldRecurse = false
                            }
                        } else {
                            shouldRecurse = false
                        }

                        if shouldRecurse {
                            await state.enqueue(entryPath, depth: depth + 1)
                        }
                    }
                }
            } catch {
                await authority.fail(with: error)
            }

            // Close box synchronously before returning
            await closeBox()
            await state.decrementActive()
        }

        private static func getInode(_ path: File.Path, io: File.IO.Executor) async -> File.Directory.Walk.Async.Inode.Key? {
            do {
                return try await io.run {
                    // Use lstat to get the symlink's own inode, not its target's
                    let info = try File.System.Stat.lstatInfo(at: path)
                    return File.Directory.Walk.Async.Inode.Key(device: info.deviceId, inode: info.inode)
                }
            } catch {
                return nil
            }
        }
    }
}
