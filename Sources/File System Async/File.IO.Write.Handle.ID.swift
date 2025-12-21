//
//  File.IO.Write.Handle.ID.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Write.Handle {
    /// A unique identifier for a registered streaming write context.
    ///
    /// IDs are:
    /// - Scoped to a specific executor instance (prevents cross-executor misuse)
    /// - Never reused within an executor's lifetime (ABA-proof)
    /// - Sendable and Hashable for use as dictionary keys
    ///
    /// Use this ID to reference an open streaming write across async boundaries.
    /// The actual write context lives in the executor's registry.
    public struct ID: Hashable, Sendable {
        /// The unique identifier within the executor.
        let raw: UInt64
        /// The scope identifier (unique per executor instance).
        let scope: UInt64
    }
}
