//
//  File.IO.Executor.Waiter.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Executor.Waiter {
    /// Sendable box to capture waiter state across isolation boundaries.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// Write-once semantics with happens-before relationship.
    ///
    /// ### Proof:
    /// 1. `state` is set exactly once in `withCheckedContinuation` body
    /// 2. Read occurs in cancellation handler which runs after body completes
    /// 3. Swift's continuation machinery establishes happens-before
    final class Box: @unchecked Sendable {
        var state: State?
    }
}
