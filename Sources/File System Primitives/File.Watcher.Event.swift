//
//  File.Watcher.Event.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Watcher {
    /// A file system event.
    public struct Event: Sendable {
        /// The path that changed.
        public let path: File.Path

        /// The type of event.
        public let type: Kind

        public init(path: File.Path, type: Kind) {
            self.path = path
            self.type = type
        }
    }
}
