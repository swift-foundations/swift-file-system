//
//  File.Directory.Walk.Undecodable.Context.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk.Undecodable {
    /// Context provided when an undecodable entry is encountered during walk.
    ///
    /// This context allows the callback to make an informed decision about
    /// how to handle the entry, and provides access to raw name bytes for
    /// diagnostics or logging.
    public struct Context: Sendable {
        /// The parent directory (which is decodable).
        public let parent: File.Path

        /// The undecodable entry name (raw bytes/code units preserved).
        ///
        /// Use `name.debugDescription` for logging or `String(lossy: name)`
        /// for a best-effort string representation.
        public let name: File.Name

        /// The type of the entry.
        public let type: File.Directory.Entry.Kind

        /// Current depth in the walk (0 = root directory).
        public let depth: Int

        /// Creates an undecodable context.
        ///
        /// - Parameters:
        ///   - parent: The parent directory path.
        ///   - name: The undecodable entry name.
        ///   - type: The type of the entry.
        ///   - depth: Current depth in the walk.
        public init(
            parent: File.Path,
            name: File.Name,
            type: File.Directory.Entry.Kind,
            depth: Int
        ) {
            self.parent = parent
            self.name = name
            self.type = type
            self.depth = depth
        }
    }
}
