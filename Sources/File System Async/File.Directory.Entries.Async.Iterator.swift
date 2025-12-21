//
//  File.Directory.Entries.Async.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Entries.Async {
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
        private typealias Box = File.IO.Blocking.Threads.Iterator.Box<File.Directory.Iterator>

        private enum State {
            case unopened
            case open(Box)
            case finished
        }

        private let path: File.Path
        private let io: File.IO.Executor
        private var state: State = .unopened
        private var buffer: [Element] = []
        private var cursor: Int = 0
        internal let batchSize: Int

        init(path: File.Path, io: File.IO.Executor, batchSize: Int = 64) {
            self.path = path
            self.io = io
            self.batchSize = batchSize
        }

        deinit {
            // INVARIANT: deinit never spawns tasks or performs async cleanup.
            // Users must call terminate() for deterministic resource release.
            #if DEBUG
            if case .open = state {
                print("Warning: Entries.Async.Iterator deallocated without terminate() for path: \(path)")
            }
            #endif
        }

        public func next() async throws -> Element? {
            // Loop instead of recursion to avoid stack growth
            while true {
                // Check cancellation before any work
                try Task.checkCancellation()

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

        private func open() async throws {
            // INVARIANT: IteratorBox only touched inside io.run
            let box = try await io.run { [path] in
                let iterator = try File.Directory.Iterator.open(at: path)
                return Box(iterator)
            }
            state = .open(box)
            buffer = []
            cursor = 0
        }

        private func refill(_ box: Box) async throws {
            let batchSize = self.batchSize

            do {
                // INVARIANT: IteratorBox only touched inside io.run
                let entries = try await io.run {
                    var batch: [Element] = []
                    batch.reserveCapacity(batchSize)
                    for _ in 0..<batchSize {
                        // withValue returns nil if box is closed, next() returns nil at EOF
                        guard let maybeEntry = try box.withValue({ try $0.next() }),
                              let entry = maybeEntry else { break }
                        batch.append(entry)
                    }
                    return batch
                }

                buffer = entries
                cursor = 0

                if entries.isEmpty {
                    // EOF - close handle on executor
                    // INVARIANT: IteratorBox only touched inside io.run
                    await closeBox(box)
                    state = .finished
                }
            } catch is CancellationError {
                // Cancelled - cleanup deterministically before rethrowing
                // INVARIANT: IteratorBox only touched inside io.run
                await closeBox(box)
                state = .finished
                throw CancellationError()
            } catch {
                // Other error - close handle and rethrow
                // INVARIANT: IteratorBox only touched inside io.run
                await closeBox(box)
                state = .finished
                throw error
            }
        }

        private func closeBox(_ box: Box) async {
            // INVARIANT: IteratorBox only touched inside io.run
            _ = try? await io.run {
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
