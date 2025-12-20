//
//  File.IO.HandleID.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// A unique identifier for a registered file handle.
    ///
    /// HandleIDs are:
    /// - Scoped to a specific executor/store instance (prevents cross-executor misuse)
    /// - Never reused within an executor's lifetime
    /// - Sendable and Hashable for use as dictionary keys
    public struct HandleID: Hashable, Sendable {
        /// The unique identifier within the store.
        let raw: UInt64
        /// The scope identifier (unique per store instance).
        let scope: UInt64
    }
}
