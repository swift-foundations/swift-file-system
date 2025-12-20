//
//  File.IO.Executor.WaiterState.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

/// Token for cancellation-safe waiter tracking with single-owner semantics.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Thread-safe state transitions protected by Mutex.
///
/// ### Proof:
/// 1. All access to `state` occurs inside `lock.withLock`
/// 2. State transitions are atomic (check + update + resume in single critical section)
/// 3. Each continuation is resumed exactly once (state machine prevents double-resume)
final class _WaiterState: @unchecked Sendable {
    enum State {
        case waiting(CheckedContinuation<Void, Never>)
        case resumed
        case cancelled
    }

    private let lock: Mutex<State>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.lock = Mutex(.waiting(continuation))
    }

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

/// Sendable box to capture waiter state across isolation boundaries.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Write-once semantics with happens-before relationship.
///
/// ### Proof:
/// 1. `state` is set exactly once in `withCheckedContinuation` body
/// 2. Read occurs in cancellation handler which runs after body completes
/// 3. Swift's continuation machinery establishes happens-before
final class _WaiterBox: @unchecked Sendable {
    var state: _WaiterState?
}

/// Sendable box to track cancellation state across isolation boundaries.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Single-writer (cancellation handler), read after synchronization.
///
/// ### Proof:
/// 1. Only written by cancellation handler (single writer)
/// 2. Read occurs after continuation resumes (happens-before via continuation)
/// 3. Value indicates whether cancel() was called, not precise timing
final class _CancellationBox: @unchecked Sendable {
    var value: Bool = false
}
