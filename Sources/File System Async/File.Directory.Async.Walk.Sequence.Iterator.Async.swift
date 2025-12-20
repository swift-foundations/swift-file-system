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
