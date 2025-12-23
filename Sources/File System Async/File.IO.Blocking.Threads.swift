//
//  File.IO.Blocking.Threads.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Blocking {
    /// A lane implementation backed by dedicated OS threads.
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
    public final class Threads: Sendable {
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

// MARK: - Capabilities

extension File.IO.Blocking.Threads {
    public var capabilities: File.IO.Blocking.Capabilities {
        File.IO.Blocking.Capabilities(
            executesOnDedicatedThreads: true,
            guaranteesRunOnceEnqueued: true
        )
    }
}

// MARK: - runBoxed (for Lane factory)

extension File.IO.Blocking.Threads {
    /// Execute a boxed operation - used by Lane factory.
    /// The operation returns a boxed Result (already containing any error).
    /// Threads only throws Lane.Failure for infrastructure failures.
    public func runBoxed(
        deadline: File.IO.Blocking.Deadline?,
        _ operation: @Sendable @escaping () -> UnsafeMutableRawPointer
    ) async throws(File.IO.Blocking.Lane.Failure) -> UnsafeMutableRawPointer {
        // Check cancellation upfront
        do {
            try Task.checkCancellation()
        } catch {
            throw .cancelled
        }

        // Lazy start workers
        runtime.startIfNeeded()

        // Check shutdown
        let isShutdown = runtime.state.lock.withLock { runtime.state.isShutdown }
        if isShutdown {
            throw .shutdown
        }

        let state = runtime.state
        let options = runtime.options

        // Use non-throwing continuation - result comes through return value
        let result: Result<UnsafeMutableRawPointer, File.IO.Blocking.Lane.Failure> =
            await withCheckedContinuation {
                (
                    continuation: CheckedContinuation<
                        Result<UnsafeMutableRawPointer, File.IO.Blocking.Lane.Failure>, Never
                    >
                ) in

                let job = Job.Instance(operation: operation) { ptr in
                    continuation.resume(returning: .success(ptr))
                }

                state.lock.lock()

                // Double-check shutdown
                if state.isShutdown {
                    state.lock.unlock()
                    continuation.resume(returning: .failure(.shutdown))
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
                    continuation.resume(returning: .failure(.queueFull))

                case .suspend:
                    // Create pending job and wait for capacity
                    let token = state.generateToken()
                    state.lock.unlock()

                    // Use Task to handle the async wait
                    Task { [state, deadline] in
                        // Non-throwing continuation for pending wait
                        let waitResult: Result<Void, File.IO.Blocking.Lane.Failure> =
                            await withCheckedContinuation {
                                (
                                    pendingCont: CheckedContinuation<
                                        Result<Void, File.IO.Blocking.Lane.Failure>, Never
                                    >
                                ) in

                                state.lock.lock()

                                // Check if shutdown happened while we were setting up
                                if state.isShutdown {
                                    state.lock.unlock()
                                    pendingCont.resume(returning: .failure(.shutdown))
                                    return
                                }

                                // Check if capacity became available
                                if !state.queue.isFull {
                                    state.queue.enqueue(job)
                                    state.lock.signal()
                                    state.lock.unlock()
                                    pendingCont.resume(returning: .success(()))
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
                                            cancelled.continuation.resume(
                                                returning: .failure(.deadlineExceeded)
                                            )
                                        } else {
                                            state.lock.unlock()
                                        }
                                    }
                                }
                            }

                        // Check for failure in waiting
                        switch waitResult {
                        case .success:
                            // Job was enqueued - the job itself will resume the outer continuation
                            break
                        case .failure(let failure):
                            // Waiting failed - resume outer continuation with failure
                            continuation.resume(returning: .failure(failure))
                        }
                    }
                }
            }

        return try result.get()
    }

    public func shutdown() async {
        guard runtime.isStarted else { return }

        let state = runtime.state

        // Set shutdown flag and collect pending jobs
        let pendingJobs: [Pending.Job] = state.lock.withLock {
            guard !state.isShutdown else { return [] }
            state.isShutdown = true

            // Drain all pending capacity waiters
            let pending = state.pendingQueue.drainAll()

            return pending
        }

        // Wake all workers
        state.lock.broadcast()

        // Resume pending jobs with shutdown failure (outside lock)
        for pending in pendingJobs {
            pending.continuation.resume(returning: .failure(.shutdown))
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
                        try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
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
