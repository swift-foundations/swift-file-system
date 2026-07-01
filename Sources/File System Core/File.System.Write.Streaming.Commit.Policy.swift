// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

extension File.System.Write.Streaming.Commit {
    /// Controls how chunks are committed to disk.
    public enum Policy: Sendable {
        /// Atomic write via temp file + rename (crash-safe).
        ///
        /// - Write chunks to temp file in same directory
        /// - Sync temp file according to durability
        /// - Atomically rename to destination
        /// - Sync directory to persist rename
        case atomic(File.System.Write.Streaming.Atomic.Options = .init())

        /// Direct write to destination (faster, no crash-safety).
        ///
        /// On crash or cancellation, file may be partially written.
        case direct(File.System.Write.Streaming.Direct.Options = .init())
    }
}
