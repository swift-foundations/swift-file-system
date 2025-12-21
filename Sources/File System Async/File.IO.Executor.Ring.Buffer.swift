//
//  File.IO.Executor.Ring.Buffer.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// O(1) enqueue/dequeue queue using circular buffer.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// Only accessed from actor-isolated context.
///
/// ### Proof:
/// 1. All mutations occur within `Executor` actor methods
/// 2. Actor isolation guarantees serial access
/// 3. The struct itself has no internal synchronization needs
extension File.IO.Executor.Ring {
    struct Buffer<T>: @unchecked Sendable {
        private var storage: [T?]
        private var head: Int = 0
        private var tail: Int = 0
        private var _count: Int = 0

        init(capacity: Int) {
            storage = [T?](repeating: nil, count: max(capacity, 16))
        }
    }
}

extension File.IO.Executor.Ring.Buffer {
    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    mutating func enqueue(_ element: T) {
        if _count == storage.count {
            grow()
        }
        storage[tail] = element
        tail = (tail + 1) % storage.count
        _count += 1
    }

    mutating func dequeue() -> T? {
        guard _count > 0 else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % storage.count
        _count -= 1
        return element
    }

    /// Drain all elements.
    mutating func drainAll() -> [T] {
        var result: [T] = []
        result.reserveCapacity(_count)
        while let element = dequeue() {
            result.append(element)
        }
        return result
    }

    private mutating func grow() {
        var newStorage = [T?](repeating: nil, count: storage.count * 2)
        for i in 0..<_count {
            newStorage[i] = storage[(head + i) % storage.count]
        }
        head = 0
        tail = _count
        storage = newStorage
    }
}
