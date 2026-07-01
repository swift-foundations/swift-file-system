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
    /// Options for atomic streaming writes.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Durability

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Durability = .full
        ) {
            self.strategy = strategy
            self.durability = durability
        }
    }
}
