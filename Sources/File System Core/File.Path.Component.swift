//
//  File.Path.Component.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import ASCII
public import Paths
public import Strings

extension File.Path {
    /// A single component of a file path.
    ///
    /// A component represents a single directory or file name within a path.
    /// For example, in `/usr/local/bin`, the components are `usr`, `local`, and `bin`.
    ///
    /// `File.Path.Component` is a typealias for `Paths.Path.Component`.
    public typealias Component = Paths.Path.Component
}

// MARK: - Byte-Level Initialization (POSIX)

#if !os(Windows)
    extension File.Path.Component {
        /// Creates a validated component from raw UTF-8 bytes.
        ///
        /// POSIX semantics: only rejects `/` (0x2F) and `NUL` (0x00).
        /// Backslash and control characters are allowed on POSIX systems.
        ///
        /// - Parameter bytes: The UTF-8 encoded component bytes.
        /// - Throws: `Paths.Path.Component.Error` if the bytes are empty, contain forbidden characters,
        ///           or cannot be decoded as valid UTF-8.
        @inlinable
        public init<Bytes: Swift.Sequence>(utf8 bytes: Bytes) throws(Paths.Path.Component.Error)
        where Bytes.Element == UInt8 {
            // Collect bytes while checking for forbidden chars
            var collected: [UInt8] = []
            for byte in bytes {
                // POSIX: only / (0x2F) and NUL (0x00) are forbidden
                if byte == 0x2F || byte == 0x00 {
                    throw .containsPathSeparator
                }
                collected.append(byte)
            }

            guard !collected.isEmpty else { throw .empty }

            // Convert to String for Path.Component bridge
            guard let string = Swift.String.strictUTF8(collected) else {
                throw .invalidUTF8
            }

            try self.init(string)
        }

        /// Creates a validated component from an UnsafeBufferPointer of UTF-8 bytes.
        ///
        /// POSIX semantics: only rejects `/` (0x2F) and `NUL` (0x00).
        /// This overload avoids intermediate allocation when the buffer is already available.
        ///
        /// - Parameter buffer: The UTF-8 encoded component bytes.
        /// - Throws: `Paths.Path.Component.Error` if the buffer is empty, contains forbidden characters,
        ///           or cannot be decoded as valid UTF-8.
        @inlinable
        public init(utf8 buffer: UnsafeBufferPointer<UInt8>) throws(Paths.Path.Component.Error) {
            guard !buffer.isEmpty else { throw .empty }

            // POSIX: only / (0x2F) and NUL (0x00) are forbidden.
            // Uses `contains(where:)` rather than a `for unsafe byte in` loop:
            // swift-format 6.3.2 corrupts the `for unsafe <var> in` strict-memory-
            // safety syntax (merges `unsafe byte` → `unsafebyte`).
            if unsafe buffer.contains(where: { $0 == 0x2F || $0 == 0x00 }) {
                throw .containsPathSeparator
            }

            // Convert to String for Path.Component bridge
            guard let string = unsafe Swift.String.strictUTF8(Array(buffer)) else {
                throw .invalidUTF8
            }

            try self.init(string)
        }
    }
#endif
