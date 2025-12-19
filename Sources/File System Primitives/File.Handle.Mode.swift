//
//  File.Handle.Mode.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Handle {
    /// The mode in which a file handle was opened.
    public enum Mode: Sendable {
        /// Read-only access.
        case read
        /// Write-only access.
        case write
        /// Read and write access.
        case readWrite
        /// Append-only access.
        case append
    }
}

// MARK: - RawRepresentable

extension File.Handle.Mode: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .read: return 0
        case .write: return 1
        case .readWrite: return 2
        case .append: return 3
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .read
        case 1: self = .write
        case 2: self = .readWrite
        case 3: self = .append
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Handle.Mode: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
