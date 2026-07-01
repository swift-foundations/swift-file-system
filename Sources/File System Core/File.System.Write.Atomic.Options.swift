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
    /// Options controlling atomic write behavior.
    public struct Options: Sendable {
        /// Rename strategy (replace or no-clobber).
        public var strategy: Strategy

        /// Durability guarantee level.
        public var durability: File.System.Write.Durability

        /// Which metadata to preserve from the original file.
        public var preservation: Preservation

        /// Ownership preservation behavior.
        public var ownership: Ownership

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Durability = .full,
            preservation: Preservation = .permissions,
            ownership: Ownership = .ignore
        ) {
            self.strategy = strategy
            self.durability = durability
            self.preservation = preservation
            self.ownership = ownership
        }
    }
}
