//
//  File.IO.Executor.Cancellation.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Executor.Cancellation {
    /// Sendable box to track cancellation state across isolation boundaries.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// Single-writer (cancellation handler), read after synchronization.
    ///
    /// ### Proof:
    /// 1. Only written by cancellation handler (single writer)
    /// 2. Read occurs after continuation resumes (happens-before via continuation)
    /// 3. Value indicates whether cancel() was called, not precise timing
    final class Box: @unchecked Sendable {
        var value: Bool = false
    }
}
