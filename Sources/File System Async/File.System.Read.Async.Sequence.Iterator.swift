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
        private let channel: AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>
        private var channelIterator:
            AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>.AsyncIterator
        private var producerTask: Task<Void, Never>?
        private var isFinished = false

        private init(
            channel: AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>,
            channelIterator: AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>
                .AsyncIterator
        ) {
            self.channel = channel
            self.channelIterator = channelIterator
        }

        /// Factory method to create iterator and start producer.
        /// Uses factory pattern to avoid init-region isolation issues.
        static func make(path: File.Path, chunkSize: Int, io: File.IO.Executor) -> Iterator {
            let channel = AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>()
            let iterator = Iterator(
                channel: channel,
                channelIterator: channel.makeAsyncIterator()
            )

            // Capture only Sendable values, not self
            let path = path
            let chunkSize = chunkSize
            let io = io
            iterator.producerTask = Task {
                await Self.runProducer(
                    path: path,
                    chunkSize: chunkSize,
                    io: io,
                    channel: channel
                )
            }

            return iterator
        }

        deinit {
            producerTask?.cancel()
        }

        public func next() async throws(File.IO.Error<File.Handle.Error>) -> Element? {
            guard !isFinished else { return nil }

            do {
                try Task.checkCancellation()
                let result = try await channelIterator.next()
                if result == nil {
                    isFinished = true
                }
                return result
            } catch let error as File.IO.Error<File.Handle.Error> {
                isFinished = true
                producerTask?.cancel()
                throw error
            } catch is CancellationError {
                isFinished = true
                producerTask?.cancel()
                throw .cancelled
            } catch {
                isFinished = true
                producerTask?.cancel()
                throw .operation(.readFailed(errno: 0, message: "Unknown error: \(error)"))
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
            io: File.IO.Executor,
            channel: AsyncThrowingChannel<Element, File.IO.Error<File.Handle.Error>>
        ) async {
            // Open file and register with executor
            let handleResult: Result<File.IO.Handle.ID, File.IO.Error<File.Handle.Error>> = await {
                do {
                    let id = try await io.openFile(path, mode: .read)
                    return .success(id)
                } catch let error as File.IO.Error<File.Handle.Error> {
                    return .failure(error)
                } catch is CancellationError {
                    return .failure(.cancelled)
                } catch {
                    return .failure(
                        .operation(.openFailed(errno: 0, message: "Open failed: \(error)"))
                    )
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

            } catch let error as File.IO.Error<File.Handle.Error> {
                // Error - clean up and propagate
                try? await io.destroyHandle(handleId)
                channel.fail(error)

            } catch {
                // Defensive - should not happen with typed executor
                try? await io.destroyHandle(handleId)
                channel.fail(.operation(.readFailed(errno: 0, message: "Unknown error: \(error)")))
            }
        }
    }
}
