//
//  File.IO.Executor.Handle.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Executor.Handle {
    /// Internal entry in the handle registry.
    ///
    /// Uses a class to hold the non-copyable File.Handle.
    /// Actor isolation ensures thread safety without @unchecked Sendable.
    final class Entry {
        /// The file handle, or nil if currently checked out.
        var handle: File.Handle?

        /// Queue of tasks waiting for this handle.
        var waiters: Waiters

        /// Whether destroy has been requested.
        var isDestroyed: Bool

        init(handle: consuming File.Handle) {
            self.handle = consume handle
            self.waiters = Waiters()
            self.isDestroyed = false
        }
    }
}
