//
//  File.IO.HandleBox.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO {
    /// A heap-allocated box that owns a File.Handle with its own lock.
    ///
    /// This design enables:
    /// - Per-handle locking (parallelism across different handles)
    /// - Stable storage address (dictionary rehashing doesn't invalidate inout)
    /// - Safe concurrent access patterns
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - All access to `storage` occurs within `state.withLock { }`.
    /// - The `UnsafeMutablePointer` provides a stable address for inout access
    ///   to the ~Copyable File.Handle.
    /// - No closure passed to withLock is async or escaping.
    final class HandleBox: @unchecked Sendable {
        /// State protecting the handle storage.
        /// - `true`: handle is open (storage is valid)
        /// - `false`: handle is closed (storage is nil)
        private let state: Mutex<Bool>

        /// Pointer to the handle storage. Only accessed under state lock.
        /// Nil means closed.
        private var storage: UnsafeMutablePointer<File.Handle>?

        /// The path (for diagnostics).
        let path: File.Path
        /// The mode (for diagnostics).
        let mode: File.Handle.Mode

        init(_ handle: consuming File.Handle) {
            self.path = handle.path
            self.mode = handle.mode
            // Allocate and initialize storage
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume handle)
            self.state = Mutex(true)
        }

        deinit {
            // If storage still exists, we need to clean up.
            // Note: Close errors are intentionally discarded in deinit
            // (deinit is leak prevention only).
            if let ptr = storage {
                let handle = ptr.move()
                ptr.deallocate()
                _ = try? handle.close()
            }
        }

        /// Whether the handle is still open.
        var isOpen: Bool {
            state.withLock { $0 }
        }

        /// Execute a closure with exclusive access to the handle.
        ///
        /// - Parameter body: Closure receiving inout access to the handle.
        ///   Must be synchronous and non-escaping.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.handleClosed` if handle was already closed.
        func withHandle<T>(_ body: (inout File.Handle) throws -> T) throws -> T {
            try state.withLock { isOpen in
                guard isOpen, let ptr = storage else {
                    throw HandleError.handleClosed
                }
                // Access via pointer - stable address, no move required
                return try body(&ptr.pointee)
            }
        }

        /// Close the handle and return any error.
        ///
        /// - Returns: The close error, if any.
        /// - Note: Idempotent - second call returns nil.
        func close() -> (any Error)? {
            // First, atomically mark as closed and get storage
            let ptr: UnsafeMutablePointer<File.Handle>? = state.withLock { isOpen in
                guard isOpen, let ptr = storage else {
                    return nil  // Already closed
                }
                isOpen = false
                storage = nil
                return ptr
            }

            // If already closed, return nil
            guard let ptr else {
                return nil
            }

            // Move out, deallocate, close (outside lock)
            let handle = ptr.move()
            ptr.deallocate()

            do {
                try handle.close()
                return nil
            } catch {
                return error
            }
        }
    }
}
