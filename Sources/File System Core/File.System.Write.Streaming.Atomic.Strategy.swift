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

extension File.System.Write.Streaming.Atomic {
    /// Strategy for atomic streaming writes.
    public enum Strategy: Sendable {
        /// Replace existing file (default).
        case replaceExisting

        /// Fail if destination already exists.
        ///
        /// Uses platform-specific atomic mechanisms:
        /// - macOS/iOS: `renamex_np` with `RENAME_EXCL`
        /// - Linux: `renameat2` with `RENAME_NOREPLACE`, fallback to `link+unlink`
        /// - Windows: `MoveFileExW` without `MOVEFILE_REPLACE_EXISTING`
        case noClobber
    }
}
