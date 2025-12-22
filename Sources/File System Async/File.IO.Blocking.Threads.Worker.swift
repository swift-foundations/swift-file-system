//
//  File.IO.Blocking.Threads.Worker.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Blocking.Threads {
    /// Worker loop running on a dedicated OS thread.
    ///
    /// ## Design
    /// Each worker:
    /// 1. Waits for jobs on the shared queue (via condition variable)
    /// 2. Executes jobs to completion
    /// 3. Signals capacity waiters when queue space becomes available
    /// 4. Exits when shutdown flag is set and queue is drained
    struct Worker {
        let id: Int
        let state: State
    }
}

extension File.IO.Blocking.Threads.Worker {
    /// The main worker loop.
    ///
    /// Runs until shutdown is signaled and all jobs are drained.
    func run() {
        while true {
            // Acquire lock and wait for job
            state.lock.lock()

            // Wait for job or shutdown
            while state.queue.isEmpty && !state.isShutdown {
                state.lock.wait()
            }

            // Check for exit condition: shutdown + empty queue
            if state.isShutdown && state.queue.isEmpty {
                state.lock.unlock()
                return
            }

            // Dequeue job
            guard let job = state.queue.dequeue() else {
                state.lock.unlock()
                continue
            }

            state.inFlightCount += 1

            // Admit one pending job if any (queue now has capacity)
            if let pending = state.pendingQueue.popFirst() {
                state.queue.enqueue(pending.job)
                // Resume the pending caller with success (they are now enqueued)
                pending.continuation.resume(returning: .success(()))
                // Signal that another job is available for workers
                state.lock.signal()
            }

            state.lock.unlock()

            // Execute job outside lock
            job.run()

            // Mark completion
            state.lock.lock()
            state.inFlightCount -= 1
            // If shutdown and queue empty and no in-flight, signal (for shutdown wait)
            if state.isShutdown && state.queue.isEmpty && state.inFlightCount == 0 {
                state.lock.broadcast()
            }
            state.lock.unlock()
        }
    }
}
