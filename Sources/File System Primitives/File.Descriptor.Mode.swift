//
//  File.Descriptor.Mode.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Binary

extension File.Descriptor {
    /// The mode in which to open a file descriptor.
    public enum Mode: Sendable {
        /// Read-only access.
        case read
        /// Write-only access.
        case write
        /// Read and write access.
        case readWrite
    }
}

// MARK: - RawRepresentable

extension File.Descriptor.Mode: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .read: return 0
        case .write: return 1
        case .readWrite: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .read
        case 1: self = .write
        case 2: self = .readWrite
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Descriptor.Mode: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
