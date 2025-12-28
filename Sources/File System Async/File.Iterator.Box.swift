//
//  File.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File {
    /// Namespace for iterator-related types.
    package enum Iterator {}
}

extension File.Iterator {
    /// A heap-allocated box for non-copyable iterators.
    ///
    /// ## Design
    /// This type allows non-copyable iterators (like `File.Directory.Iterator`)
    /// to be used across async boundaries by boxing them on the heap.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `fs.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern via lane serialization
    ///
    /// ## Lifecycle Contract
    /// Callers MUST call `close(_:)` before the box is deallocated.
    /// Use `terminate()` on the owning iterator for deterministic cleanup.
    /// A DEBUG warning is printed if close() is not called.
    package final class Box<T: ~Copyable>: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<T>?

        package init(_ value: consuming T) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume value)
        }

        deinit {
            guard let ptr = storage else { return }

            #if DEBUG
                print(
                    """
                    Warning: File.Iterator.Box deallocated without close().
                    Call terminate() on the owning iterator for deterministic cleanup.
                    Falling back to synchronous cleanup in deinit.
                    """
                )
            #endif

            // Best-effort cleanup to prevent resource leaks in production.
            // The iterator's deinit will close the underlying directory handle.
            ptr.deinitialize(count: 1)
            ptr.deallocate()
        }

        package var hasValue: Bool { storage != nil }

        package func withValue<R, E: Error>(
            _ body: (inout T) throws(E) -> R
        ) throws(E) -> R? {
            guard let ptr = storage else { return nil }
            return try body(&ptr.pointee)
        }

        package func close(_ cleanup: (consuming T) -> Void) {
            guard let ptr = storage else { return }
            let value = ptr.move()
            ptr.deallocate()
            storage = nil
            cleanup(consume value)
        }
    }
}
