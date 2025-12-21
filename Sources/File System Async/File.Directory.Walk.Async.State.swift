//
//  File.Directory.Walk.Async.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

/// Actor-protected state for the walk algorithm.
extension File.Directory.Walk.Async {
    actor State {
        private var queue: [(path: File.Path, depth: Int)] = []
        private var activeWorkers: Int = 0
        private var visited: Set<Inode.Key> = []

        private let maxConcurrency: Int
        private var semaphoreValue: Int
        private var semaphoreWaiters: [CheckedContinuation<Void, Never>] = []
        private var completionWaiters: [CheckedContinuation<Void, Never>] = []

        init(maxConcurrency: Int) {
            self.maxConcurrency = maxConcurrency
            self.semaphoreValue = maxConcurrency
        }

        var hasWork: Bool {
            !queue.isEmpty || activeWorkers > 0
        }

        func enqueue(_ path: File.Path, depth: Int) {
            queue.append((path, depth))
            activeWorkers += 1
            // Wake one completion waiter
            if let waiter = completionWaiters.first {
                completionWaiters.removeFirst()
                waiter.resume()
            }
        }

        func dequeue() -> (path: File.Path, depth: Int)? {
            guard !queue.isEmpty else { return nil }
            return queue.removeFirst()
        }

        func decrementActive() {
            activeWorkers = max(0, activeWorkers - 1)
            // Wake completion waiters
            if let waiter = completionWaiters.first {
                completionWaiters.removeFirst()
                waiter.resume()
            }
        }

        func waitForWorkOrCompletion() async {
            guard queue.isEmpty && activeWorkers > 0 else { return }
            await withCheckedContinuation { continuation in
                completionWaiters.append(continuation)
            }
        }

        /// Returns true if this is the first visit (should recurse), false if already visited (cycle).
        func markVisited(_ inode: Inode.Key) -> Bool {
            visited.insert(inode).inserted
        }

        func acquireSemaphore() async {
            if semaphoreValue > 0 {
                semaphoreValue -= 1
            } else {
                await withCheckedContinuation { continuation in
                    semaphoreWaiters.append(continuation)
                }
            }
        }

        func releaseSemaphore() {
            if !semaphoreWaiters.isEmpty {
                semaphoreWaiters.removeFirst().resume()
            } else {
                semaphoreValue += 1
            }
        }
    }
}
