//
//  File.IO.Handle.Store.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Handle.Store {
    /// Internal state protected by the store's mutex.
    struct State: ~Copyable {
        /// The handle storage.
        var handles: [File.IO.Handle.ID: File.IO.Handle.Box] = [:]
        /// Counter for generating unique IDs.
        var nextID: UInt64 = 0
        /// Whether the store has been shut down.
        var isShutdown: Bool = false
    }
}
