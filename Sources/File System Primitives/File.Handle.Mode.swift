//
//  File.Handle.Mode.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Handle {
    /// The mode in which a file handle was opened.
    ///
    /// This is an OptionSet allowing combinations:
    /// - `.read` - read-only access
    /// - `.write` - write-only access
    /// - `[.read, .write]` - read and write access
    /// - `.append` - append-only access (writes go to end)
    /// - `[.read, .append]` - read anywhere, append writes
    public struct Mode: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Read access.
        public static let read = Mode(rawValue: 1 << 0)

        /// Write access.
        public static let write = Mode(rawValue: 1 << 1)

        /// Append access (writes go to end of file).
        ///
        /// Can be combined with `.read` for read-anywhere, append-writes mode.
        public static let append = Mode(rawValue: 1 << 2)
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
