//
//  File.System.Write.Atomic.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Write.Atomic {
    /// Controls behavior when the destination file already exists.
    public enum Strategy: Sendable {
        /// Replace the existing file atomically (default).
        case replaceExisting

        /// Fail if the destination already exists.
        case noClobber
    }
}

// MARK: - RawRepresentable

extension File.System.Write.Atomic.Strategy: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .replaceExisting: return 0
        case .noClobber: return 1
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .replaceExisting
        case 1: self = .noClobber
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic.Strategy: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
