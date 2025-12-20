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

        public init(
            strategy: Strategy = .truncate,
            durability: File.System.Write.Streaming.Durability = .full
        ) {
            self.strategy = strategy
            self.durability = durability
        }
    }
}
