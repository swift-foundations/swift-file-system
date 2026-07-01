//
//  File.Directory.Walk.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Walk {
    /// Options for directory traversal.
    public struct Options: Sendable {
        /// Maximum depth to traverse (nil for unlimited).
        public var maxDepth: Int?

        /// Whether to follow symbolic links.
        public var followSymlinks: Bool

        /// Whether to include hidden files.
        public var includeHidden: Bool

        /// Callback invoked when an entry with an undecodable name is encountered.
        ///
        /// Default: `.skip` (do not emit, do not descend).
        public var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy

        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true,
            onUndecodable: @escaping @Sendable (Undecodable.Context) -> Undecodable.Policy = { _ in
                .skip
            }
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
            self.onUndecodable = onUndecodable
        }
    }
}
