//
//  File.Directory.Contents.Async.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Contents.Async {
    /// Pull-based async iterator for directory entries.
    ///
    /// ## Design
    /// Consumer-driven iteration with batched refills. One `io.run` call per batch,
    /// eliminating the overhead of producer Task + AsyncThrowingChannel.
    ///
    /// ## Explicit Termination
    /// Call `terminate()` for deterministic cleanup instead of relying on deinit.
    /// This is especially important in contexts where deinit timing is uncertain.
    ///
    /// ## Thread Safety
    /// This iterator is task-confined. Do not share across Tasks.
    /// The non-Sendable conformance enforces this at compile time.
    ///
    /// ## HARD INVARIANT
    /// - All observable effects on IteratorBox (`withValue`, `close`) occur exclusively
    ///   inside `io.run` closures.
    /// - IteratorBox.deinit performs no cleanup.
    /// - Deterministic cleanup requires exhausting the iterator or calling `terminate()`.
    /// - Iterator.deinit may schedule best-effort cleanup via `io.run`, but never
    ///   touches IteratorBox directly.
    public final class Iterator: AsyncIteratorProtocol {
        public typealias Element = File.Directory.Entry
        private typealias Box = File.Iterator.Box<File.Directory.Iterator>

        private enum State {
            case unopened
            case open(Box)
            case finished
        }

        private let directory: File.Directory
        private let fs: File.System.Async
        private var state: State = .unopened
        private var buffer: [Element] = []
        private var cursor: Int = 0
        internal let batchSize: Int

        init(directory: File.Directory, fs: File.System.Async, batchSize: Int = 64) {
            self.directory = directory
            self.fs = fs
            self.batchSize = batchSize
        }

        deinit {
            // INVARIANT: deinit never spawns tasks or performs async cleanup.
            // Users must call terminate() for deterministic resource release.
            #if DEBUG
                if case .open = state {
                    print(
                        "Warning: Contents.Async.Iterator deallocated without terminate() for directory: \(directory)"
                    )
                }
            #endif
        }

        public func next() async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Iterator.Error>>) -> Element? {
            // Loop instead of recursion to avoid stack growth
            while true {
                // Check cancellation before any work
                if Task.isCancelled {
                    throw .failure(.cancelled)
                }

                // Return buffered entry if available
                if cursor < buffer.count {
                    defer { cursor += 1 }
                    return buffer[cursor]
                }

                // Buffer exhausted - refill or finish
                switch state {
                case .unopened:
                    try await open()
                    continue  // Loop to read first batch

                case .open(let box):
                    try await refill(box)
                    if buffer.isEmpty {
                        return nil  // EOF
                    }
                    continue  // Loop to return first entry

                case .finished:
                    return nil
                }
            }
        }

        private func open() async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Iterator.Error>>) {
            // INVARIANT: IteratorBox only touched inside io.run
            // Explicit typed throws in closure signature for proper inference
            let openOperation: @Sendable () throws(File.Directory.Iterator.Error) -> Box = {
                [directory] () throws(File.Directory.Iterator.Error) -> Box in
                try Box(File.Directory.Iterator.open(at: directory))
            }
            let box = try await fs.run(openOperation)
            state = .open(box)
            buffer = []
            cursor = 0
        }

        private func refill(_ box: Box) async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Iterator.Error>>) {
            let batchSize = self.batchSize

            // INVARIANT: IteratorBox only touched inside io.run
            let readOperation: @Sendable () throws(File.Directory.Iterator.Error) -> [Element] = {
                var batch: [Element] = []
                batch.reserveCapacity(batchSize)
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
                    batch.append(entry)
                }
                return batch
            }

            do {
                let entries = try await fs.run(readOperation)

                buffer = entries
                cursor = 0

                if entries.isEmpty {
                    // EOF - close handle on executor
                    // INVARIANT: IteratorBox only touched inside io.run
                    await closeBox(box)
                    state = .finished
                }
            } catch {
                // Cleanup and rethrow
                // INVARIANT: IteratorBox only touched inside io.run
                await closeBox(box)
                state = .finished
                throw error
            }
        }

        private func closeBox(_ box: Box) async {
            // INVARIANT: IteratorBox only touched inside io.run
            _ = try? await fs.run {
                box.close { $0.close() }
            }
        }

        /// Explicitly terminate iteration and release resources.
        ///
        /// Use this for deterministic cleanup instead of relying on deinit.
        /// Safe to call multiple times (idempotent).
        public func terminate() async {
            if case .open(let box) = state {
                // INVARIANT: IteratorBox only touched inside io.run
                await closeBox(box)
            }
            state = .finished
            buffer = []
        }
    }
}
