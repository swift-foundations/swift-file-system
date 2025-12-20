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

        /// The location of the entry.
        ///
        /// Contains either an absolute path (if name was decodable) or a relative
        /// reference to the parent directory (if name could not be decoded).
        public let location: Location

        /// The type of the entry.
        public let type: Kind

        /// Creates a directory entry.
        ///
        /// - Parameters:
        ///   - name: The entry's filename (raw bytes preserved).
        ///   - location: The location of the entry (absolute or relative).
        ///   - type: The type of entry (file, directory, symlink, etc.).
        public init(name: File.Name, location: Location, type: Kind) {
            self.name = name
            self.location = location
            self.type = type
        }
    }
}

// MARK: - Convenience Accessors

extension File.Directory.Entry {
    /// The absolute path, if the name was decodable.
    ///
    /// Returns `nil` if the entry has a `.relative` location (name could not be decoded).
    @inlinable
    public var path: File.Path? { location.path }

    /// The parent directory path. Always available.
    @inlinable
    public var parent: File.Path { location.parent }
}
