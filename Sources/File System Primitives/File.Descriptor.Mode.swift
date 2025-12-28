//
//  File.Descriptor.Mode.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Binary

extension File.Descriptor {
    /// The mode in which to open a file descriptor.
    ///
    /// This is an OptionSet allowing combinations:
    /// - `.read` - read-only access
    /// - `.write` - write-only access
    /// - `[.read, .write]` - read and write access
    public struct Mode: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Read access.
        public static let read = Mode(rawValue: 1 << 0)

        /// Write access.
        public static let write = Mode(rawValue: 1 << 1)
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
