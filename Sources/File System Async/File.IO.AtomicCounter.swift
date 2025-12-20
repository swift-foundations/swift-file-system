//
//  File.IO.AtomicCounter.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

/// Thread-safe counter for generating unique IDs.
///
/// ## Safety Invariant
/// All mutations of `value` occur inside `withLock`, ensuring exclusive access.
final class _AtomicCounter: @unchecked Sendable {
    private let state: Mutex<UInt64>

    init() {
        self.state = Mutex(0)
    }

    func next() -> UInt64 {
        state.withLock { value in
            let result = value
            value += 1
            return result
        }
    }
}
