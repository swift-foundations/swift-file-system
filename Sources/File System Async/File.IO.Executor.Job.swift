//
//  File.IO.Executor.Job.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

/// Type-erased job that encapsulates work and continuation.
protocol _Job: Sendable {
    func run()
    func fail(with error: any Error)
}

/// Typed job box that preserves static typing through execution.
///
/// ## Safety
/// Uses `Mutex<Bool>` to guard completion, ensuring exactly-once semantics
/// even if call sites evolve (e.g., adding "cancel queued jobs" logic).
///
/// ### Invariant:
/// - `run()` and `fail()` are idempotent - only first call resumes continuation
/// - Continuation is resumed outside the lock to avoid deadlock
final class _JobBox<T: Sendable>: @unchecked Sendable, _Job {
    let operation: @Sendable () throws -> T
    private let continuation: CheckedContinuation<T, any Error>
    private let completed = Mutex(false)

    init(
        operation: @Sendable @escaping () throws -> T,
        continuation: CheckedContinuation<T, any Error>
    ) {
        self.operation = operation
        self.continuation = continuation
    }

    private func tryComplete(_ body: () -> Void) {
        let shouldRun = completed.withLock { flag in
            if flag { return false }
            flag = true
            return true
        }
        if shouldRun { body() }
    }

    func run() {
        tryComplete {
            continuation.resume(with: Result { try operation() })
        }
    }

    func fail(with error: any Error) {
        tryComplete {
            continuation.resume(throwing: error)
        }
    }
}
