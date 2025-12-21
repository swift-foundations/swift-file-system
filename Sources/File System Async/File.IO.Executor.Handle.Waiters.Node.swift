//
//  File.IO.Executor.Handle.Waiters.Node.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Executor.Handle.Waiters {
    /// A single waiter node in the queue.
    struct Node {
        let token: UInt64
        let continuation: CheckedContinuation<Void, Never>
        var isCancelled: Bool = false
    }
}
