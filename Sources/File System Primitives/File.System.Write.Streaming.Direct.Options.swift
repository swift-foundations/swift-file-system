//
//  File.System.Write.Streaming.Direct.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Direct {
    /// Options for non-atomic (direct) writes.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Streaming.Durability

        /// Expected total size in bytes. When provided on macOS/iOS, enables
        /// preallocation via `fcntl(F_PREALLOCATE)` which can significantly
        /// improve write throughput for large files (up to 2x faster).
        ///
        /// ## Tradeoffs
        /// - **Pro**: Reduces APFS metadata updates during sequential writes
        /// - **Con**: Changes ENOSPC behavior - fails upfront if space unavailable
        /// - **Con**: Preallocates even if actual write is smaller
        ///
        /// Only used when total size is known upfront (e.g., bulk writes).
        /// Ignored for streaming writes where total size is unknown.
        public var expectedSize: Int64?

        public init(
            strategy: Strategy = .truncate,
            durability: File.System.Write.Streaming.Durability = .full,
            expectedSize: Int64? = nil
        ) {
            self.strategy = strategy
            self.durability = durability
            self.expectedSize = expectedSize
        }
    }
}
