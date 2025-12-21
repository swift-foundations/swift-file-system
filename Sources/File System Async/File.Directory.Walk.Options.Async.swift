//
//  File.Directory.Walk.Options.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Walk.Async {
    /// Options for async recursive directory walking.
    ///
    /// Includes all base walk options plus async-specific settings.
    public struct Options: Swift.Sendable {
        /// Maximum depth to traverse (nil for unlimited).
        public var maxDepth: Int?

        /// Whether to follow symbolic links.
        ///
        /// When `true`, cycle detection via inode tracking is enabled.
        public var followSymlinks: Bool

        /// Whether to include hidden files.
        public var includeHidden: Bool

        /// Callback invoked when an entry with an undecodable name is encountered.
        public var onUndecodable:
            @Sendable (File.Directory.Walk.Undecodable.Context) ->
                File.Directory.Walk.Undecodable.Policy

        /// Maximum concurrent directory reads.
        public var maxConcurrency: Int

        /// Creates async walk options.
        ///
        /// - Parameters:
        ///   - maxDepth: Maximum depth to traverse (nil for unlimited).
        ///   - followSymlinks: Follow symlinks (default: false).
        ///   - includeHidden: Include hidden files (default: true).
        ///   - onUndecodable: Callback for undecodable entries (default: skip).
        ///   - maxConcurrency: Maximum concurrent reads (default: 8).
        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true,
            onUndecodable:
                @escaping @Sendable (File.Directory.Walk.Undecodable.Context) ->
                File.Directory.Walk.Undecodable.Policy = { _ in .skip },
            maxConcurrency: Int = 8
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
            self.onUndecodable = onUndecodable
            self.maxConcurrency = max(1, maxConcurrency)
        }
    }
}

// MARK: - Transformation from Base Options

extension File.Directory.Walk.Async.Options {
    /// Creates async walk options from base walk options.
    ///
    /// - Parameters:
    ///   - base: The base walk options to transform.
    ///   - maxConcurrency: Maximum concurrent reads (default: 8).
    public init(_ base: File.Directory.Walk.Options, maxConcurrency: Int = 8) {
        self.maxDepth = base.maxDepth
        self.followSymlinks = base.followSymlinks
        self.includeHidden = base.includeHidden
        self.onUndecodable = base.onUndecodable
        self.maxConcurrency = max(1, maxConcurrency)
    }
}
