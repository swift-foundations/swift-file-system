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

extension File.System.Write.Streaming {
    /// Options controlling streaming write behavior.
    public struct Options: Sendable {
        /// How to commit chunks to disk.
        public var commit: Commit.Policy

        public init(
            commit: Commit.Policy = .atomic(.init())
        ) {
            self.commit = commit
        }
    }
}
