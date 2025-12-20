//
//  File.Directory.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Directory {
    /// A directory entry representing a file or subdirectory.
    public struct Entry: Sendable {
        /// The name of the entry.
        public let name: String

        /// The full path to the entry.
        public let path: File.Path

        /// The type of the entry.
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

// MARK: - Entry.Kind

extension File.Directory.Entry {
    /// The kind of a directory entry.
    public enum Kind: Sendable {
        /// A regular file.
        case file
        /// A directory (folder).
        case directory
        /// A symbolic link pointing to another path.
        case symbolicLink
        /// Block device, character device, socket, FIFO, or unknown type.
        case other
    }
}

// MARK: - Backward Compatibility

extension File.Directory {
    @available(*, deprecated, renamed: "Entry.Kind")
    public typealias EntryType = Entry.Kind
}

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

// MARK: - RawRepresentable

extension File.Directory.Entry.Kind: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .file: return 0
        case .directory: return 1
        case .symbolicLink: return 2
        case .other: return 3
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .file
        case 1: self = .directory
        case 2: self = .symbolicLink
        case 3: self = .other
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Directory.Entry.Kind: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
