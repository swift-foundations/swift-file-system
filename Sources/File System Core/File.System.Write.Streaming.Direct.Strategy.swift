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

extension File.System.Write.Streaming.Direct {
    /// Strategy for direct (non-atomic) writes.
    public enum Strategy: Sendable {
        /// Fail if destination exists.
        case create

        /// Truncate existing file or create new.
        case truncate
    }
}
