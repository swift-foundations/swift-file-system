//
//  File.Directory.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory {
    /// A directory entry representing a file or subdirectory.
    public struct Entry: Sendable {
        /// The name of the entry.
        ///
        /// Uses `File.Name` to preserve raw filesystem encoding. Use `String(entry.name)`
        /// for strict decoding, or `String(lossy: entry.name)` for a guaranteed (but
        /// potentially lossy) string representation.
        public let name: File.Name

        /// The full path to the entry.
        public let path: File.Path

        /// The type of the entry.
        public let type: Kind

        /// Creates a directory entry.
        ///
        /// - Parameters:
        ///   - name: The entry's filename (not the full path).
        ///   - path: The full path to the entry.
        ///   - type: The type of entry (file, directory, symlink, etc.).
        public init(name: File.Name, path: File.Path, type: Kind) {
            self.name = name
            self.path = path
            self.type = type
        }
    }
}
