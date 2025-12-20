//
//  File.IO.HandleStore.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Synchronization

extension File.IO {
    /// Thread-safe storage for file handles, owned by an executor.
    ///
    /// ## Design
    /// - Dictionary maps HandleID → HandleBox
    /// - Store mutex guards map mutations and shutdown state
    /// - Per-handle locks (in HandleBox) guard handle operations
    /// - This enables parallelism across different handles
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - All mutation of `state` contents occurs inside `state.withLock { }`.
    /// - Boxes are never returned to users; only accessed inside io.run jobs.
    /// - No closure passed to withLock is async or escaping.
    ///
    /// ## Lifecycle
    /// - Store lifetime = Executor lifetime
    /// - Shutdown forcibly closes remaining handles
    final class HandleStore: @unchecked Sendable {
        /// Protected state containing dictionary and metadata.
        private let state: Mutex<HandleStoreState>

        /// Unique scope identifier for this store instance.
        let scope: UInt64

        /// Global counter for generating unique scope IDs.
        private static let scopeCounter = _AtomicCounter()

        init() {
            // Generate a unique scope ID for this store instance
            self.scope = Self.scopeCounter.next()
            self.state = Mutex(HandleStoreState())
        }

        /// Register a handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: The handle ID for future operations.
        /// - Throws: `ExecutorError.shutdownInProgress` if store is shut down.
        ///
        /// ## Implementation Note
        /// The handle is consumed outside the lock because `Mutex.withLock` takes
        /// an escaping closure, and noncopyable types cannot be consumed inside
        /// escaping closures. We use a two-phase approach:
        /// 1. Quick check if shutdown in progress (return early if so)
        /// 2. Create HandleBox (consumes handle)
        /// 3. Atomically register under lock (with double-check for shutdown race)
        ///
        /// If shutdown races between phase 1 and 3, the HandleBox's deinit will
        /// close the handle as a safety net.
        func register(_ handle: consuming File.Handle) throws -> HandleID {
            let scope = self.scope

            // Phase 1: Quick shutdown check (avoid creating box if already shutdown)
            let alreadyShutdown = state.withLock { $0.isShutdown }
            if alreadyShutdown {
                _ = try? handle.close()
                throw ExecutorError.shutdownInProgress
            }

            // Phase 2: Create box (consumes handle) - outside lock
            let box = HandleBox(handle)

            // Phase 3: Atomically register (with double-check)
            return try state.withLock { state in
                guard !state.isShutdown else {
                    // Race: shutdown started after our check
                    // box.deinit will close the handle
                    throw ExecutorError.shutdownInProgress
                }

                let id = HandleID(raw: state.nextID, scope: scope)
                state.nextID += 1
                state.handles[id] = box
                return id
            }
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: `HandleError.invalidHandleID` if ID not found.
        /// - Throws: `HandleError.handleClosed` if handle was closed.
        func withHandle<T>(_ id: HandleID, _ body: (inout File.Handle) throws -> T) throws -> T {
            // Validate scope first
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Find the box (short lock on dictionary)
            let box: HandleBox? = state.withLock { state in
                state.handles[id]
            }

            guard let box else {
                throw HandleError.invalidHandleID
            }

            // Execute with per-handle lock (box has its own Mutex)
            return try box.withHandle(body)
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `HandleError.scopeMismatch` if ID belongs to different store.
        /// - Throws: Close errors from the underlying handle.
        /// - Note: Idempotent for same-scope IDs that were already closed.
        func destroy(_ id: HandleID) throws {
            // Validate scope first - scope mismatch is always an error
            guard id.scope == scope else {
                throw HandleError.scopeMismatch
            }

            // Remove from dictionary (short lock)
            let box: HandleBox? = state.withLock { state in
                state.handles.removeValue(forKey: id)
            }

            // If not found, treat as already closed (idempotent)
            guard let box else {
                return
            }

            // Close the handle (may throw)
            if let error = box.close() {
                throw error
            }
        }

        /// Shutdown the store: close all remaining handles.
        ///
        /// - Note: Close errors are logged but not propagated.
        /// - Postcondition: All handles closed, store rejects new registrations.
        func shutdown() {
            // Atomically mark shutdown and extract remaining handles
            let remainingHandles: [HandleID: HandleBox] = state.withLock { state in
                state.isShutdown = true
                let handles = state.handles
                state.handles.removeAll()
                return handles
            }

            // Close all remaining handles (best-effort, outside lock)
            for (id, box) in remainingHandles {
                if let error = box.close() {
                    #if DEBUG
                        print("Warning: Error closing handle \(id.raw) during shutdown: \(error)")
                    #endif
                }
            }
        }

        /// Check if a handle ID is valid (for diagnostics).
        func isValid(_ id: HandleID) -> Bool {
            guard id.scope == scope else { return false }
            return state.withLock { state in
                state.handles[id] != nil
            }
        }

        /// The number of registered handles (for testing).
        var count: Int {
            state.withLock { state in
                state.handles.count
            }
        }
    }
}
