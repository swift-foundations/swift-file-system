//
//  File.IO.Executor.Handle.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Executor.Handle {
    /// Lifecycle state of a handle entry.
    ///
    /// Distinguishes between:
    /// - `present`: Handle is stored and available
    /// - `checkedOut`: Handle temporarily moved for transaction
    /// - `destroyed`: Handle closed or marked for closure
    enum State {
        case present
        case checkedOut
        case destroyed
    }

    /// Internal entry in the handle registry.
    ///
    /// Uses a class to hold the non-copyable File.Handle.
    /// Actor isolation ensures thread safety without @unchecked Sendable.
    final class Entry {
        /// The file handle, or nil if currently checked out or destroyed.
        var handle: File.Handle?

        /// Queue of tasks waiting for this handle.
        var waiters: Waiters

        /// Current lifecycle state.
        var state: State

        init(handle: consuming File.Handle) {
            self.handle = consume handle
            self.waiters = Waiters()
            self.state = .present
        }

        /// Whether the handle is logically open (present or checked out).
        var isOpen: Bool {
            state == .present || state == .checkedOut
        }

        /// Legacy compatibility: whether destroy has been requested.
        var isDestroyed: Bool {
            state == .destroyed
        }
    }
}
