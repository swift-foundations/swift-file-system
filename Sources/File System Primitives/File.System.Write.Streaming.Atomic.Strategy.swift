//
//  File.System.Write.Streaming.Atomic.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

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
