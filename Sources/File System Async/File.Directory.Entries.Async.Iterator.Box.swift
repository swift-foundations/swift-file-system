//
//  File.Directory.Entries.Async.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Synchronization

extension File.Directory.Entries.Async.Iterator {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// Uses UnsafeMutablePointer for stable address with ~Copyable type,
    /// similar to Handle.Box pattern.
    ///
    /// ## Ownership Model
    /// - `close()` is thread-safe and idempotent via atomic exchange
    /// - `deinit` calls `close()` as a last-resort safety net to prevent leaks
    /// - Prefer explicit `terminate()` on Iterator for deterministic cleanup
    ///
    /// ## Thread Safety
    /// - `close()` is safe to call from any thread (atomic)
    /// - `next()` is NOT thread-safe - iterator is single-consumer
    /// - The iterator enforces single-consumer semantics at a higher level
    final class Box: @unchecked Sendable {
        // Atomic storage for thread-safe close()
        // UnsafeMutableRawPointer because Atomic requires Sendable
        private let storage: Atomic<UnsafeMutableRawPointer?>

        init(_ iterator: consuming File.Directory.Iterator) {
            let ptr: UnsafeMutablePointer<File.Directory.Iterator> = .allocate(capacity: 1)
            ptr.initialize(to: consume iterator)
            self.storage = Atomic(UnsafeMutableRawPointer(ptr))
        }

        deinit {
            // Last-resort safety net: never leak OS resources.
            // close() is idempotent via atomic exchange, so this is always safe.
            close()
        }

        func next() throws -> File.Directory.Entry? {
            // Load current pointer (non-destructive read for iteration)
            guard let raw = storage.load(ordering: .acquiring) else {
                return nil
            }
            let ptr = raw.assumingMemoryBound(to: File.Directory.Iterator.self)
            return try ptr.pointee.next()
        }

        func close() {
            // Atomically exchange storage to nil - only one thread wins
            guard let raw = storage.exchange(nil, ordering: .acquiringAndReleasing) else {
                return  // Already closed by another thread
            }
            let ptr = raw.assumingMemoryBound(to: File.Directory.Iterator.self)
            let it = ptr.move()
            ptr.deallocate()
            it.close()
        }
    }
}
