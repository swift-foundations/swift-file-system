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
    /// Controls behavior when the destination file already exists.
    public enum Strategy: UInt8, Sendable, Equatable {
        /// Replace the existing file atomically (default).
        case replaceExisting = 0

        /// Fail if the destination already exists.
        case noClobber = 1
    }
}
