//
//  File.Handle.Seek.Origin.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Binary

extension File.Handle.Seek {
    /// The origin for seek operations.
    public enum Origin: Sendable {
        /// Seek from the beginning of the file.
        case start
        /// Seek from the current position.
        case current
        /// Seek from the end of the file.
        case end
    }
}

// MARK: - RawRepresentable

extension File.Handle.Seek.Origin: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .start: return 0
        case .current: return 1
        case .end: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .start
        case 1: self = .current
        case 2: self = .end
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Handle.Seek.Origin: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
