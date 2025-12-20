//
//  File.Directory.Async.Walk.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory.Async {
    /// Options for recursive directory walking.
    public struct WalkOptions: Sendable {
        /// Maximum concurrent directory reads.
        public var maxConcurrency: Int

        /// Whether to follow symbolic links.
        ///
        /// When `true`, cycle detection via inode tracking is enabled.
        public var followSymlinks: Bool

        /// Creates walk options.
        ///
        /// - Parameters:
        ///   - maxConcurrency: Maximum concurrent reads (default: 8).
        ///   - followSymlinks: Follow symlinks (default: false).
        public init(
            maxConcurrency: Int = 8,
            followSymlinks: Bool = false
        ) {
            self.maxConcurrency = max(1, maxConcurrency)
            self.followSymlinks = followSymlinks
        }
    }
}
