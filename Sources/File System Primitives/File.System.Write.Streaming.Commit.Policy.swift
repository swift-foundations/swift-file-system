//
//  File.System.Write.Streaming.Commit.Policy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Commit {
    /// Controls how chunks are committed to disk.
    public enum Policy: Sendable {
        /// Atomic write via temp file + rename (crash-safe).
        ///
        /// - Write chunks to temp file in same directory
        /// - Sync temp file according to durability
        /// - Atomically rename to destination
        /// - Sync directory to persist rename
        ///
        /// Note: Unlike `File.System.Write.Atomic`, streaming does not support
        /// metadata preservation (timestamps, xattrs, ACLs, ownership).
        case atomic(File.System.Write.Streaming.Atomic.Options = .init())

        /// Direct write to destination (faster, no crash-safety).
        ///
        /// On crash or cancellation, file may be partially written.
        case direct(File.System.Write.Streaming.Direct.Options = .init())
    }
}
