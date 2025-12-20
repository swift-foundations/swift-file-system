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
        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            commit: Commit.Policy = .atomic(.init()),
            createIntermediates: Bool = false
        ) {
            self.commit = commit
            self.createIntermediates = createIntermediates
        }
    }
}
