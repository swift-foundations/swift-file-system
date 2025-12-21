//
//  File.Directory.Walk.Async.Completion.Authority.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

/// State machine ensuring exactly one terminal state.
///
/// States: `running` → `failed(Error)` | `cancelled` | `finished`
/// First transition out of `running` wins.
extension File.Directory.Walk.Async.Completion {
    actor Authority {
        enum State {
            case running
            case failed(any Error)
            case cancelled
            case finished
        }

        private var state: State = .running

        var isComplete: Bool {
            if case .running = state { return false }
            return true
        }

        /// Attempt to transition to failed. First error wins.
        func fail(with error: any Error) {
            guard case .running = state else { return }
            state = .failed(error)
        }

        /// Attempt to transition to cancelled.
        func cancel() {
            guard case .running = state else { return }
            state = .cancelled
        }

        /// Complete and return final state.
        func complete() -> State {
            if case .running = state {
                state = .finished
            }
            return state
        }
    }
}
