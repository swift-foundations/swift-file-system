//
//  File.IO.Executor.Waiter.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO.Executor.Waiter {
    /// Token for cancellation-safe waiter tracking with single-owner semantics.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// Thread-safe state transitions protected by Mutex.
    ///
    /// ### Proof:
    /// 1. All access to `state` occurs inside `lock.withLock`
    /// 2. State transitions are atomic (check + update + resume in single critical section)
    /// 3. Each continuation is resumed exactly once (state machine prevents double-resume)
    final class State: @unchecked Sendable {
        enum Phase {
            case waiting(CheckedContinuation<Void, Never>)
            case resumed
            case cancelled
        }

        private let lock: Mutex<Phase>

        init(_ continuation: CheckedContinuation<Void, Never>) {
            self.lock = Mutex(.waiting(continuation))
        }
    }
}

extension File.IO.Executor.Waiter.State {
    /// Resume the waiter if still waiting. Returns true if resumed.
    func resume() -> Bool {
        lock.withLock { state in
            guard case .waiting(let continuation) = state else { return false }
            state = .resumed
            continuation.resume()
            return true
        }
    }

    /// Mark as cancelled and resume if still waiting.
    @discardableResult
    func cancel() -> Bool {
        lock.withLock { state in
            guard case .waiting(let continuation) = state else { return false }
            state = .cancelled
            continuation.resume()
            return true
        }
    }
}
