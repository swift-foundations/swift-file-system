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
