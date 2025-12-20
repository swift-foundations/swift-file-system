//
//  File.System.Write.Streaming.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Options controlling streaming write behavior.
    public struct Options: Sendable {
        /// How to commit chunks to disk.
        public var commit: Commit.Policy

        public init(commit: Commit.Policy = .atomic(.init())) {
            self.commit = commit
        }
    }
}
