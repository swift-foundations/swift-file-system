//
//  File.System.Write.Streaming.Atomic.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Atomic {
    /// Options for atomic streaming writes.
    ///
    /// Note: Unlike `File.System.Write.Atomic.Options`, streaming writes do not support
    /// metadata preservation. This is a simpler options type focused on
    /// durability and existence semantics.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Streaming.Durability

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Streaming.Durability = .full
        ) {
            self.strategy = strategy
            self.durability = durability
        }
    }
}
