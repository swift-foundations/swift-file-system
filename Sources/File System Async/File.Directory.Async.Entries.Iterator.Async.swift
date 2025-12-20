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
