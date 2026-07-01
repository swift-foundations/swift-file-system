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

extension File.System.Write.Atomic {
    /// Ownership preservation behavior during atomic write.
    public enum Ownership: Sendable, Equatable {
        /// Preserve ownership (uid/gid) from the original file.
        ///
        /// - Parameter strict: If `true`, throw on ownership change failure.
        ///   If `false`, silently ignore failures (expected for non-root users).
        case preserve(strict: Bool)

        /// Do not attempt to preserve ownership.
        case ignore
    }
}
