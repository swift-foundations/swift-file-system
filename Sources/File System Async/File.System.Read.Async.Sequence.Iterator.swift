//
//  File.System.Read.Async.Sequence.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import AsyncAlgorithms

extension File.System.Read.Async.Sequence {
    /// The async iterator for byte streaming.
    ///
    /// ## Thread Safety
    /// This iterator is task-confined. Do not share across Tasks.
    /// The non-Sendable conformance enforces this at compile time.
    public final class Iterator: AsyncIteratorProtocol {
        private typealias ChannelError = IO.Lifecycle.Error<IO.Error<File.Handle.Error>>

        private let channel: AsyncThrowingChannel<Element, ChannelError>
        private var channelIterator: AsyncThrowingChannel<Element, ChannelError>.AsyncIterator
        private var producerTask: Task<Void, Never>?
        private var isFinished = false

        private init(
            channel: AsyncThrowingChannel<Element, ChannelError>,
            channelIterator: AsyncThrowingChannel<Element, ChannelError>.AsyncIterator
        ) {
            self.channel = channel
            self.channelIterator = channelIterator
        }

        /// Factory method to create iterator and start producer.
        /// Uses factory pattern to avoid init-region isolation issues.
        static func make(path: File.Path, chunkSize: Int, fs: File.System.Async) -> Iterator {
            let channel = AsyncThrowingChannel<Element, ChannelError>()
            let iterator = Iterator(
                channel: channel,
                channelIterator: channel.makeAsyncIterator()
            )

            // Capture only Sendable values, not self
            let path = path
            let chunkSize = chunkSize
            let fs = fs
            iterator.producerTask = Task {
                await Self.runProducer(
                    path: path,
                    chunkSize: chunkSize,
                    fs: fs,
                    channel: channel
                )
            }

            return iterator
        }

        deinit {
            producerTask?.cancel()
        }

        public func next() async throws(IO.Lifecycle.Error<IO.Error<File.Handle.Error>>) -> Element? {
            guard !isFinished else { return nil }

            // Check cancellation without throwing (avoids mixing throw types)
            if Task.isCancelled {
                isFinished = true
                producerTask?.cancel()
                throw .failure(.cancelled)
            }

            // Pure typed throws from channel - no cast needed
            do {
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

        /// Explicitly terminate streaming and wait for cleanup to complete.
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

        // MARK: - Producer

        private static func runProducer(
            path: File.Path,
            chunkSize: Int,
            fs: File.System.Async,
            channel: AsyncThrowingChannel<Element, ChannelError>
        ) async {
            // Open file and register with pool
            let handleId: IO.Handle.ID
            do {
                handleId = try await fs.open(path, mode: .read)
            } catch {
                // error is typed as IO.Lifecycle.Error<IO.Error<File.Handle.Error>>
                channel.fail(error)
                return
            }

            // Stream chunks
            do {
                while true {
                    // Check cancellation without throwing (avoids mixing throw types)
                    if Task.isCancelled {
                        break
                    }

                    // Read chunk - allocate inside closure for Sendable safety
                    let chunk: [UInt8] = try await fs.transaction(handleId) { (handle: inout File.Handle) throws(File.Handle.Error) in
                        try handle.read(count: chunkSize)
                    }

                    // EOF
                    if chunk.isEmpty {
                        break
                    }

                    // Check cancellation before sending
                    if Task.isCancelled {
                        break
                    }

                    // Yield owned chunk
                    await channel.send(chunk)
                }

                // Clean close
                try? await fs.close(handleId)
                channel.finish()

            } catch {
                // error is typed as IO.Lifecycle.Error<IO.Error<File.Handle.Error>>
                try? await fs.close(handleId)
                channel.fail(error)
            }
        }
    }
}
