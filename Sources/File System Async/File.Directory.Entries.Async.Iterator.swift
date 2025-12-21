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
    /// ## Two-Tier Invariant
    /// 1. **Primary rule**: While executor is operational, all Box operations (`next`, `close`)
    ///    occur exclusively inside `io.run` closures for thread-safety.
    /// 2. **Shutdown rule**: If `io.run` fails (executor shutdown), direct close is permitted
    ///    as last-resort cleanup to prevent OS resource leaks.
    /// 3. **Unique ownership**: At `deinit`, we have unique ownership with no concurrent access,
    ///    so direct close is safe and prevents leaks.
    /// 4. Deterministic cleanup requires exhausting the iterator or calling `terminate()`.
    public final class Iterator: AsyncIteratorProtocol {
        public typealias Element = File.Directory.Entry

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
            // At deinit, we have unique ownership - no concurrent access is possible.
            // Direct close is safe here and prevents resource leaks.
            if case .open(let box) = state {
                #if DEBUG
                print("Warning: Entries.Async.Iterator deallocated without terminate() for path: \(path)")
                #endif
                box.close()
            }
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
            // INVARIANT: Iterator.Box only touched inside io.run
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

            // Wrap in cancellation handler to ensure cleanup on cancellation
            try await withTaskCancellationHandler {
                do {
                    // INVARIANT: Iterator.Box only touched inside io.run
                    let entries = try await io.run {
                        var batch: [Element] = []
                        batch.reserveCapacity(batchSize)
                        for _ in 0..<batchSize {
                            guard let entry = try box.next() else { break }
                            batch.append(entry)
                        }
                        return batch
                    }

                    buffer = entries
                    cursor = 0

                    if entries.isEmpty {
                        // EOF - close handle on executor
                        // INVARIANT: Iterator.Box only touched inside io.run
                        await closeBox(box)
                        state = .finished
                    }
                } catch is CancellationError {
                    // Cancellation - close via io.run
                    // INVARIANT: Iterator.Box only touched inside io.run
                    // Note: onCancel may also schedule close, but close() is idempotent
                    // and io.run serializes the calls
                    await closeBox(box)
                    state = .finished
                    throw CancellationError()
                } catch {
                    // Other error - close handle and rethrow
                    // INVARIANT: Iterator.Box only touched inside io.run
                    await closeBox(box)
                    state = .finished
                    throw error
                }
            } onCancel: { [io = self.io, box] in
                // Cancellation during io.run: schedule cleanup via io.run
                // Note: This runs on arbitrary thread, but only schedules a Task
                // Two-tier invariant: io.run while operational, direct close on shutdown
                // close() is thread-safe via atomic exchange, so concurrent close is safe
                Task.detached {
                    do {
                        try await io.run {
                            box.close()
                        }
                    } catch {
                        // Executor failed (shutdown) - close directly to prevent leaks
                        box.close()
                    }
                }
            }
        }

        private func closeBox(_ box: Box) async {
            // Two-tier invariant:
            // 1. Primary: Box operations via io.run while executor is operational
            // 2. Shutdown: Direct close is permitted to prevent resource leaks
            do {
                try await io.run {
                    box.close()
                }
            } catch {
                // Executor failed (shutdown or other) - close directly to prevent leaks.
                // Box.close() is idempotent, so this is safe even if another path also closes.
                box.close()
            }
        }

        /// Explicitly terminate iteration and release resources.
        ///
        /// Use this for deterministic cleanup instead of relying on deinit.
        /// Safe to call multiple times (idempotent).
        public func terminate() async {
            if case .open(let box) = state {
                // INVARIANT: Iterator.Box only touched inside io.run
                await closeBox(box)
            }
            state = .finished
            buffer = []
        }
    }
}
