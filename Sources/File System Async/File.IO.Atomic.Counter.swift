//
//  File.IO.Atomic.Counter.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO.Atomic {
    /// Thread-safe counter for generating unique IDs.
    ///
    /// Uses Synchronization.Mutex which is Sendable in Swift 6+.
    final class Counter: Sendable {
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
}
