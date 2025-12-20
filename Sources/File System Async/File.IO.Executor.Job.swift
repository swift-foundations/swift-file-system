//
//  File.IO.Executor.Job.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Type-erased job that encapsulates work and continuation.
protocol _Job: Sendable {
    func run()
    func fail(with error: any Error)
}

/// Typed job box that preserves static typing through execution.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Single-owner semantics with idempotent completion.
///
/// ### Proof:
/// 1. `isCompleted` guard prevents double-resume
/// 2. Each job is dequeued by exactly one worker thread
/// 3. `run()` and `fail()` are idempotent - second call is no-op
final class _JobBox<T: Sendable>: @unchecked Sendable, _Job {
    let operation: @Sendable () throws -> T
    private let continuation: CheckedContinuation<T, any Error>
    private var isCompleted = false  // Single-owner guard

    init(
        operation: @Sendable @escaping () throws -> T,
        continuation: CheckedContinuation<T, any Error>
    ) {
        self.operation = operation
        self.continuation = continuation
    }

    func run() {
        guard !isCompleted else { return }  // Idempotent
        isCompleted = true
        continuation.resume(with: Result { try operation() })
    }

    func fail(with error: any Error) {
        guard !isCompleted else { return }  // Idempotent
        isCompleted = true
        continuation.resume(throwing: error)
    }
}
