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
        public let name: String

        /// The full path to the entry.
        public let path: File.Path

        /// The kind of the entry.
        public let kind: Kind

        /// Creates a directory entry.
        ///
        /// - Parameters:
        ///   - name: The entry's filename (not the full path).
        ///   - path: The full path to the entry.
        ///   - kind: The kind of entry (file, directory, symlink, etc.).
        public init(name: String, path: File.Path, kind: Kind) {
            self.name = name
            self.path = path
            self.kind = kind
        }
    }
}

// MARK: - Backward Compatibility

extension File.Directory.Entry {
    /// Backward compatible property - use `kind` instead.
    @available(*, deprecated, renamed: "kind")
    public var type: Kind { kind }

    /// Backward compatible initializer.
    @available(*, deprecated, message: "Use init(name:path:kind:) instead")
    public init(name: String, path: File.Path, type: Kind) {
        self.init(name: name, path: path, kind: type)
    }
}
