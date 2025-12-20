//
//  File.System.Write.Streaming.Durability.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Controls durability guarantees for streaming writes.
    public enum Durability: Sendable {
        /// Full durability - both data and metadata synced.
        /// Uses `F_FULLFSYNC` on Darwin, `fsync` elsewhere.
        case full

        /// Data-only sync - metadata may not be persisted.
        /// Uses `F_BARRIERFSYNC` on Darwin, `fdatasync` on Linux.
        case dataOnly

        /// No sync - rely on OS buffers.
        /// Faster but data may be lost on power failure.
        case none
    }
}
