//
//  File.Directory.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory {
    /// A directory entry representing a file or subdirectory.
    ///
    /// Stores the raw file name and parent path. The full path is computed
    /// lazily on demand via `path()` to avoid per-entry allocation overhead.
    public struct Entry: Sendable {
        /// The name of the entry.
        ///
        /// Uses `File.Name` to preserve raw filesystem encoding. Use `String(entry.name)`
        /// for strict decoding, or `String(lossy: entry.name)` for a guaranteed (but
        /// potentially lossy) string representation.
        public let name: File.Name

        /// The parent directory path.
        public let parent: File.Path

        /// The type of the entry.
        public let type: Kind

        /// Creates a directory entry.
        ///
        /// - Parameters:
        ///   - name: The entry's filename (raw bytes preserved).
        ///   - parent: The parent directory path.
        ///   - type: The type of entry (file, directory, symlink, etc.).
        public init(name: File.Name, parent: File.Path, type: Kind) {
            self.name = name
            self.parent = parent
            self.type = type
        }
    }
}

// MARK: - Path Computation

extension File.Directory.Entry {
    /// The absolute path, computed on demand.
    ///
    /// Throws if the name cannot be decoded as valid UTF-8 or contains
    /// forbidden path characters.
    ///
    /// - Returns: The full path to this entry.
    /// - Throws: `File.Path.Component.Error` if the name is invalid.
    @inlinable
    public func path() throws(File.Path.Component.Error) -> File.Path {
        #if os(Windows)
            guard let nameString = String(name) else {
                throw .invalid
            }
            let component = try File.Path.Component(nameString)
        #else
            // Use direct byte access for typed throws compatibility
            let component = try File.Path.Component(utf8: name._rawBytes)
        #endif
        return File.Path(parent, appending: component)
    }

    /// The absolute path, or nil if invalid.
    ///
    /// Use `path()` for the throwing version with error details.
    @inlinable
    public var pathIfValid: File.Path? {
        try? path()
    }
}
