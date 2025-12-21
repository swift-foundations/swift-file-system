//
//  File.IO.Executor.Job.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO.Executor {
    /// Typed job box that preserves static typing through execution.
    ///
    /// ## Safety
    /// Uses `Mutex<Bool>` to guard completion, ensuring exactly-once semantics
    /// even if call sites evolve (e.g., adding "cancel queued jobs" logic).
    ///
    /// ### Invariant:
    /// - `run()` and `fail()` are idempotent - only first call resumes continuation
    /// - Continuation is resumed outside the lock to avoid deadlock
    ///
    /// ## Note
    /// This is named `JobBox` rather than `Job.Box` because Swift doesn't allow
    /// nesting types inside protocols (Job is a protocol).
    final class JobBox<T: Sendable>: @unchecked Sendable, Job {
        let operation: @Sendable () throws -> T
        private let continuation: CheckedContinuation<T, any Swift.Error>
        private let completed = Mutex(false)

        init(
            operation: @Sendable @escaping () throws -> T,
            continuation: CheckedContinuation<T, any Swift.Error>
        ) {
            self.operation = operation
            self.continuation = continuation
        }
    }
}

extension File.IO.Executor.JobBox {
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

    func fail(with error: any Swift.Error) {
        tryComplete {
            continuation.resume(throwing: error)
        }
    }
}
