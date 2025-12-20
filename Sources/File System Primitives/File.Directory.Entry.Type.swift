//
//  File.Directory.Entry.Kind.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Directory.Entry {
    /// The type of a directory entry.
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
