//
//  File.IO.HandleStore.State.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// Internal state protected by the store's mutex.
    struct HandleStoreState: ~Copyable {
        /// The handle storage.
        var handles: [HandleID: HandleBox] = [:]
        /// Counter for generating unique IDs.
        var nextID: UInt64 = 0
        /// Whether the store has been shut down.
        var isShutdown: Bool = false
    }
}
