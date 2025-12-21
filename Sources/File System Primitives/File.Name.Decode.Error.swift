//
//  File.Name.Decode.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import RFC_4648

extension File.Name.Decode {
    /// Error thrown when decoding a `File.Name` to `String` fails.
    ///
    /// This error preserves the undecodable name so callers can:
    /// - Report diagnostics with raw byte information
    /// - Retry with lossy decoding if appropriate
    /// - Handle the entry using raw filesystem operations
    public struct Error: Swift.Error, Sendable, Equatable {
        /// The undecodable name (raw bytes/code units preserved).
        public let name: File.Name

        /// Creates a decode error for the given undecodable name.
        public init(name: File.Name) {
            self.name = name
        }
    }
}

// MARK: - CustomStringConvertible

extension File.Name.Decode.Error: CustomStringConvertible {
    public var description: String {
        "File.Name.Decode.Error: \(name.debugDescription)"
    }
}

// MARK: - Debug Representation

extension File.Name.Decode.Error {
    /// Debug description of the raw bytes (hex encoded).
    ///
    /// Useful for logging and diagnostics when a filename cannot be decoded.
    public var debugRawBytes: String {
        #if os(Windows)
            // Convert UInt16 code units to bytes (big-endian) for hex encoding
            var bytes: [UInt8] = []
            bytes.reserveCapacity(name._rawCodeUnits.count * 2)
            for codeUnit in name._rawCodeUnits {
                bytes.append(UInt8(codeUnit >> 8))
                bytes.append(UInt8(codeUnit & 0xFF))
            }
            return bytes.hex.encoded(uppercase: true)
        #else
            return name._rawBytes.hex.encoded(uppercase: true)
        #endif
    }
}
