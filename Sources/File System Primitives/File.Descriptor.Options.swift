//
//  File.Descriptor.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Binary

extension File.Descriptor {
    /// Options for opening a file descriptor.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Create the file if it doesn't exist.
        public static let create = Options(rawValue: 1 << 0)

        /// Truncate the file to zero length if it exists.
        public static let truncate = Options(rawValue: 1 << 1)

        /// Fail if the file already exists (used with `.create`).
        public static let exclusive = Options(rawValue: 1 << 2)

        /// Append to the file.
        public static let append = Options(rawValue: 1 << 3)

        /// Do not follow symbolic links.
        public static let noFollow = Options(rawValue: 1 << 4)

        /// Close the file descriptor on exec.
        public static let closeOnExec = Options(rawValue: 1 << 5)
    }
}

// MARK: - Binary.Serializable

extension File.Descriptor.Options: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}
