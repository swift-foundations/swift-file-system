//
//  File.IO.Blocking.Threads.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Blocking {
    /// A lane backed by dedicated OS threads.
    ///
    /// ## Design
    /// - Spawns dedicated OS threads that do not interfere with Swift's cooperative pool.
    /// - Bounded queue with configurable backpressure policy.
    /// - Jobs run to completion once enqueued (mutation semantics guaranteed).
    ///
    /// ## Capabilities
    /// - `executesOnDedicatedThreads`: true
    /// - `guaranteesRunOnceEnqueued`: true
    ///
    /// ## Backpressure
    /// - `.suspend`: Callers wait for queue capacity (bounded by deadline).
    /// - `.throw`: Callers receive `.queueFull` immediately if queue is full.
    public final class Threads: Lane, Sendable {
        private let runtime: Runtime

        /// Creates a Threads lane with the given options.
        public init(_ options: Options = .init()) {
            self.runtime = Runtime(options: options)
        }

        deinit {
            // If not properly shut down, force shutdown synchronously
            if runtime.isStarted && !runtime.state.isShutdown {
                runtime.state.lock.withLock {
                    runtime.state.isShutdown = true
                }
                runtime.state.lock.broadcast()
                runtime.joinAllThreads()
            }
        }
    }
}

// MARK: - Lane Conformance

extension File.IO.Blocking.Threads {
    public var capabilities: File.IO.Blocking.Capabilities {
        File.IO.Blocking.Capabilities(
            executesOnDedicatedThreads: true,
            guaranteesRunOnceEnqueued: true
        )
    }

    public func run<T: Sendable>(
        deadline: File.IO.Blocking.Deadline?,
        _ operation: @Sendable @escaping () throws -> T
    ) async throws -> T {
        // Check cancellation upfront
        try Task.checkCancellation()

        // Lazy start workers
        runtime.startIfNeeded()

        // Check shutdown
        let isShutdown = runtime.state.lock.withLock { runtime.state.isShutdown }
        if isShutdown {
            throw Error.shutdown
        }

        // Create job and enqueue (with backpressure handling)
        let state = runtime.state
        let options = runtime.options
        return try await withCheckedThrowingContinuation { continuation in
            let job = Job.Instance(operation: operation, continuation: continuation)

            state.lock.lock()

            // Double-check shutdown
            if state.isShutdown {
                state.lock.unlock()
                continuation.resume(throwing: Error.shutdown)
                return
            }

            // Try to enqueue directly
            if !state.queue.isFull {
                state.queue.enqueue(job)
                state.lock.signal()
                state.lock.unlock()
                return
            }

            // Queue is full - handle based on backpressure policy
            switch options.backpressure {
            case .throw:
                state.lock.unlock()
                continuation.resume(throwing: Error.queueFull)

            case .suspend:
                // Create pending job and wait for capacity
                let token = state.generateToken()
                state.lock.unlock()

                // Use Task to handle the async wait
                Task { [state, deadline] in
                    do {
                        try await withTaskCancellationHandler {
                            try await withCheckedThrowingContinuation { (pendingCont: CheckedContinuation<Void, any Swift.Error>) in
                                state.lock.lock()

                                // Check if shutdown happened while we were setting up
                                if state.isShutdown {
                                    state.lock.unlock()
                                    pendingCont.resume(throwing: Error.shutdown)
                                    return
                                }

                                // Check if capacity became available
                                if !state.queue.isFull {
                                    state.queue.enqueue(job)
                                    state.lock.signal()
                                    state.lock.unlock()
                                    pendingCont.resume()
                                    return
                                }

                                // Still full - add to pending queue
                                let pending = Pending.Job(
                                    token: token,
                                    job: job,
                                    continuation: pendingCont
                                )
                                state.pendingQueue.append(pending)
                                state.lock.unlock()

                                // Handle deadline in a separate task if needed
                                if let deadline = deadline {
                                    Task {
                                        let remaining = deadline.remainingNanoseconds
                                        if remaining > 0 {
                                            try? await Task.sleep(nanoseconds: remaining)
                                        }
                                        // Check if still pending
                                        state.lock.lock()
                                        if let cancelled = state.pendingQueue.cancel(token: token) {
                                            state.lock.unlock()
                                            cancelled.continuation.resume(throwing: Error.deadlineExceeded)
                                        } else {
                                            state.lock.unlock()
                                        }
                                    }
                                }
                            }
                        } onCancel: {
                            // Cancel the pending job
                            state.lock.lock()
                            if let cancelled = state.pendingQueue.cancel(token: token) {
                                state.lock.unlock()
                                cancelled.continuation.resume(throwing: CancellationError())
                            } else {
                                state.lock.unlock()
                            }
                        }
                    } catch {
                        // The pending continuation already handled the error
                    }
                }
            }
        }
    }

    public func shutdown() async {
        guard runtime.isStarted else { return }

        let state = runtime.state

        // Set shutdown flag and fail pending jobs
        let pendingJobs: [Pending.Job] = state.lock.withLock {
            guard !state.isShutdown else { return [] }
            state.isShutdown = true

            // Fail all pending capacity waiters
            let pending = state.pendingQueue.drainAll()

            return pending
        }

        // Wake all workers
        state.lock.broadcast()

        // Resume pending jobs with shutdown error (outside lock)
        for pending in pendingJobs {
            pending.continuation.resume(throwing: Error.shutdown)
        }

        // Wait for in-flight jobs to complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let done = state.lock.withLock {
                state.inFlightCount == 0 && state.queue.isEmpty
            }

            if done {
                continuation.resume()
            } else {
                // Poll for completion
                Task {
                    while true {
                        let complete = state.lock.withLock {
                            state.inFlightCount == 0 && state.queue.isEmpty
                        }
                        if complete { break }
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    }
                    continuation.resume()
                }
            }
        }

        // Join all threads
        runtime.joinAllThreads()
    }
}

// MARK: - Options

extension File.IO.Blocking.Threads {
    /// Configuration options for the Threads lane.
    public struct Options: Sendable {
        /// Number of worker threads.
        public var workers: Int

        /// Maximum number of jobs in the queue.
        public var queueLimit: Int

        /// Backpressure policy when queue is full.
        public var backpressure: Backpressure

        /// Creates options with the given values.
        ///
        /// - Parameters:
        ///   - workers: Number of workers (default: processor count).
        ///   - queueLimit: Maximum queue size (default: 256).
        ///   - backpressure: Backpressure policy (default: `.suspend`).
        public init(
            workers: Int? = nil,
            queueLimit: Int = 256,
            backpressure: Backpressure = .suspend
        ) {
            self.workers = max(1, workers ?? File.IO.Blocking.Threads.processorCount)
            self.queueLimit = max(1, queueLimit)
            self.backpressure = backpressure
        }
    }
}

// MARK: - Backpressure

extension File.IO.Blocking.Threads {
    /// Backpressure policy when the queue is full.
    public enum Backpressure: Sendable {
        /// Suspend the caller until capacity is available.
        ///
        /// Bounded by the deadline if provided.
        case suspend

        /// Throw `.queueFull` immediately.
        case `throw`
    }
}

// MARK: - Error

extension File.IO.Blocking.Threads {
    /// Errors thrown by the Threads lane.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Queue is full (when backpressure is `.throw`).
        case queueFull

        /// Deadline expired while waiting for queue capacity.
        case deadlineExceeded

        /// Lane is shut down.
        case shutdown
    }
}
