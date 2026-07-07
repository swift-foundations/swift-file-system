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
    /// Options for non-atomic (direct) writes.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Durability

        /// Expected total size in bytes. When provided on macOS/iOS, enables
        /// preallocation via `fcntl(F_PREALLOCATE)` which can significantly
        /// improve write throughput for large files.
        ///
        /// ## Tradeoffs
        /// - **Pro**: Reduces APFS metadata updates during sequential writes
        /// - **Con**: Changes ENOSPC behavior - fails upfront if space unavailable
        /// - **Con**: Preallocates even if actual write is smaller
        ///
        /// Only used when total size is known upfront, such as for bulk writes.
        /// Ignored for streaming writes where total size is unknown.
        public var expectedSize: Int64?

        public init(
            strategy: Strategy = .truncate,
            durability: File.System.Write.Durability = .full,
            expectedSize: Int64? = nil
        ) {
            self.strategy = strategy
            self.durability = durability
            self.expectedSize = expectedSize
        }
    }
}
