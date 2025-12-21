//
//  File.IO.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO {
    /// Namespace for iterator-related types.
    public enum Iterator {}
}

extension File.IO.Iterator {
    /// A heap-allocated box for non-copyable iterators.
    ///
    /// ## Design
    /// This type allows non-copyable iterators (like `File.Directory.Iterator`)
    /// to be used across async boundaries by boxing them on the heap.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `io.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern via executor serialization
    ///
    /// ## Lifecycle Contract
    /// Callers MUST call `close(_:)` before the box is deallocated.
    /// Use `terminate()` on the owning iterator for deterministic cleanup.
    /// A DEBUG warning is printed if close() is not called.
    public final class Box<T: ~Copyable>: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<T>?

        public init(_ value: consuming T) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume value)
        }

        deinit {
            // Per plan: "allowed to print debug warning, but must not spawn tasks
            // or perform best-effort cleanup"
            #if DEBUG
                if storage != nil {
                    print(
                        """
                        Warning: File.IO.Iterator.Box deallocated without close().
                        This violates the io.run-only invariant.
                        Use terminate() on the owning iterator for deterministic cleanup.
                        """
                    )
                }
            #endif
        }

        public var hasValue: Bool { storage != nil }

        public func withValue<R>(_ body: (inout T) throws -> R) rethrows -> R? {
            guard let ptr = storage else { return nil }
            return try body(&ptr.pointee)
        }

        public func close(_ cleanup: (consuming T) -> Void) {
            guard let ptr = storage else { return }
            let value = ptr.move()
            ptr.deallocate()
            storage = nil
            cleanup(consume value)
        }
    }
}
