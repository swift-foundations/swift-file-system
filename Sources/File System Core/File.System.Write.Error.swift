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

extension File.System.Write {
    /// Internal error for shared write operations.
    ///
    /// Both `Atomic` and `Streaming` APIs catch and remap
    /// to their domain-specific error types.
    internal enum Error: Swift.Error, Sendable {
        case sync(Swift.String)
        case close(Swift.String)
        case rename(from: File.Path, to: File.Path, Swift.String)
        case exists(path: File.Path)
        case directory(path: File.Path, Swift.String)
        case write(written: Int, expected: Int, Swift.String)
        case random(Swift.String)
    }
}
