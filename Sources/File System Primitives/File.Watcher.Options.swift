//
//  File.Watcher.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Watcher {
    /// Options for file watching.
    public struct Options: Sendable {
        /// Whether to watch subdirectories recursively.
        public var recursive: Bool

        /// Latency in seconds before coalescing events.
        public var latency: Double

        public init(
            recursive: Bool = false,
            latency: Double = 0.5
        ) {
            self.recursive = recursive
            self.latency = latency
        }
    }
}
