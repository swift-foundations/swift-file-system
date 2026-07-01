//
//  File.Name.Decode.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import Strings

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
    public var description: Swift.String {
        "File.Name.Decode.Error: \(Swift.String(describing: name))"
    }
}

// MARK: - Debug Representation

extension File.Name.Decode.Error {
    /// Debug description of the raw bytes (hex encoded).
    ///
    /// Useful for logging and diagnostics when a filename cannot be decoded.
    /// Delegates to ``Strings/Array/platformNativeHex(uppercase:)`` (unified
    /// L3 entry point in swift-strings), which dispatches POSIX → 2-hex-digits-
    /// per-byte vs Windows → 4-hex-digits-per-UInt16-big-endian.
    public var debugRawBytes: Swift.String {
        name.rawBytes.platformNativeHex(uppercase: true)
    }
}
