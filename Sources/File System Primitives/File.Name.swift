//
//  File.Name.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import Binary
import RFC_4648

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File {
    /// A directory entry name that preserves the raw filesystem encoding.
    ///
    /// ## Strict Encoding Policy
    /// `File.Name` stores the raw bytes (POSIX) or UTF-16 code units (Windows)
    /// exactly as returned by the filesystem. This ensures:
    /// - **Referential integrity**: Names that cannot be decoded to `String` are still preserved
    /// - **Round-trip correctness**: You can always re-open a file you can iterate
    /// - **Debuggability**: Raw bytes available for diagnostics when decoding fails
    ///
    /// ## Usage
    /// ```swift
    /// for entry in try File.Directory.contents(at: path) {
    ///     if let name = String(entry.name) {
    ///         print("File: \(name)")
    ///     } else {
    ///         print("Undecodable filename: \(entry.name.debugDescription)")
    ///     }
    /// }
    /// ```
    public struct Name: Sendable, Equatable, Hashable {
        #if os(Windows)
            /// Raw UTF-16 code units from the filesystem.
            @usableFromInline
            package let _rawCodeUnits: [UInt16]
        #else
            /// Raw bytes from the filesystem.
            @usableFromInline
            package let _rawBytes: [UInt8]
        #endif

        #if os(Windows)
            /// Creates a name from raw UTF-16 code units.
            @usableFromInline
            internal init(rawCodeUnits: [UInt16]) {
                self._rawCodeUnits = rawCodeUnits
            }
        #else
            /// Creates a name from raw bytes.
            @usableFromInline
            internal init(rawBytes: [UInt8]) {
                self._rawBytes = rawBytes
            }
        #endif

        // MARK: - Semantic Predicates

        /// True if this name is "." or ".." (dot entries to skip during iteration).
        @usableFromInline
        internal var isDotOrDotDot: Bool {
            #if os(Windows)
                _rawCodeUnits == [0x002E] || _rawCodeUnits == [0x002E, 0x002E]
            #else
                _rawBytes == [0x2E] || _rawBytes == [0x2E, 0x2E]
            #endif
        }

        /// True if this name starts with '.' (hidden file convention on Unix-like systems).
        ///
        /// This is a semantic predicate - Walk uses this to filter hidden files
        /// without accessing raw storage directly.
        @inlinable
        public var isHiddenByDotPrefix: Bool {
            #if os(Windows)
                _rawCodeUnits.first == 0x002E
            #else
                _rawBytes.first == 0x2E
            #endif
        }
    }
}

// MARK: - String Conversion (Extension Inits)

extension String {
    /// Creates a string from a file name using strict UTF-8/UTF-16 decoding.
    ///
    /// Returns `nil` if the raw data contains invalid encoding.
    ///
    /// - POSIX: Returns `nil` if raw bytes are not valid UTF-8
    /// - Windows: Returns `nil` if raw code units contain invalid UTF-16 (e.g., lone surrogates)
    @inlinable
    public init?(_ fileName: File.Name) {
        #if os(Windows)
            guard let decoded = String._strictUTF16Decode(fileName._rawCodeUnits) else {
                return nil
            }
            self = decoded
        #else
            guard let decoded = String._strictUTF8Decode(fileName._rawBytes) else {
                return nil
            }
            self = decoded
        #endif
    }

    /// Creates a string from a file name using lossy decoding.
    ///
    /// Invalid sequences are replaced with the Unicode replacement character (U+FFFD).
    ///
    /// - Warning: Paths containing replacement characters cannot be used to re-open files.
    @inlinable
    public init(lossy fileName: File.Name) {
        #if os(Windows)
            self = Swift.String(decoding: fileName._rawCodeUnits, as: UTF16.self)
        #else
            self = Swift.String(decoding: fileName._rawBytes, as: UTF8.self)
        #endif
    }

    /// Creates a string from a file name using strict decoding.
    ///
    /// Throws `File.Name.Decode.Error` if the raw data contains invalid encoding,
    /// allowing callers to access the raw bytes for diagnostics.
    ///
    /// - Parameter fileName: The file name to decode.
    /// - Throws: `File.Name.Decode.Error` if decoding fails.
    @inlinable
    public init(validating fileName: File.Name) throws(File.Name.Decode.Error) {
        guard let decoded = String(fileName) else {
            throw File.Name.Decode.Error(name: fileName)
        }
        self = decoded
    }
}

// MARK: - Strict Decoding Helpers

extension String {
    #if !os(Windows)
        /// Strictly decodes UTF-8 bytes, returning `nil` on any invalid sequence.
        @usableFromInline
        package static func _strictUTF8Decode(_ bytes: [UInt8]) -> String? {
            var utf8 = UTF8()
            var iterator = bytes.makeIterator()
            var scalars: [Unicode.Scalar] = []
            scalars.reserveCapacity(bytes.count)

            while true {
                switch utf8.decode(&iterator) {
                case .scalarValue(let scalar):
                    scalars.append(scalar)
                case .emptyInput:
                    return String(String.UnicodeScalarView(scalars))
                case .error:
                    return nil
                }
            }
        }
    #endif

    #if os(Windows)
        /// Strictly decodes UTF-16 code units, returning `nil` on any invalid sequence.
        /// Rejects lone surrogates and other malformed UTF-16.
        @usableFromInline
        internal static func _strictUTF16Decode(_ codeUnits: [UInt16]) -> String? {
            var utf16 = UTF16()
            var iterator = codeUnits.makeIterator()
            var scalars: [Unicode.Scalar] = []
            scalars.reserveCapacity(codeUnits.count)

            while true {
                switch utf16.decode(&iterator) {
                case .scalarValue(let scalar):
                    scalars.append(scalar)
                case .emptyInput:
                    return String(String.UnicodeScalarView(scalars))
                case .error:
                    return nil
                }
            }
        }
    #endif
}

// MARK: - CustomStringConvertible

extension File.Name: CustomStringConvertible {
    public var description: String {
        String(self) ?? String(lossy: self)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Name: CustomDebugStringConvertible {
    /// A debug description showing raw bytes/code units when decoding fails.
    public var debugDescription: String {
        if let str = String(self) {
            return "File.Name(\"\(str)\")"
        } else {
            #if os(Windows)
                // Convert UInt16 code units to bytes (big-endian) for hex encoding
                var bytes: [UInt8] = []
                bytes.reserveCapacity(_rawCodeUnits.count * 2)
                for codeUnit in _rawCodeUnits {
                    bytes.append(UInt8(codeUnit >> 8))
                    bytes.append(UInt8(codeUnit & 0xFF))
                }
                let hex = bytes.hex.encoded(uppercase: true)
                return "File.Name(invalidUTF16: [\(hex)])"
            #else
                let hex = _rawBytes.hex.encoded(uppercase: true)
                return "File.Name(invalidUTF8: [\(hex)])"
            #endif
        }
    }
}

// MARK: - Initialization from dirent/WIN32_FIND_DATAW

extension File.Name {
    #if !os(Windows)
        /// Creates a `File.Name` from a POSIX directory entry name (d_name).
        ///
        /// Extracts raw bytes using bounded access based on actual buffer size.
        @usableFromInline
        internal init<T>(posixDirectoryEntryName dName: T) {
            self = withUnsafePointer(to: dName) { ptr in
                let bufferSize = MemoryLayout<T>.size

                return ptr.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bytes in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < bufferSize && bytes[length] != 0 {
                        length += 1
                    }

                    // Copy raw bytes
                    let rawBytes = Array(UnsafeBufferPointer(start: bytes, count: length))
                    return File.Name(rawBytes: rawBytes)
                }
            }
        }
    #endif

    #if os(Windows)
        /// Creates a `File.Name` from a Windows directory entry name (cFileName).
        ///
        /// Extracts raw UTF-16 code units using bounded access based on actual buffer size.
        @usableFromInline
        internal init<T>(windowsDirectoryEntryName cFileName: T) {
            self = withUnsafePointer(to: cFileName) { ptr in
                let bufferSize = MemoryLayout<T>.size
                let elementCount = bufferSize / MemoryLayout<UInt16>.size

                return ptr.withMemoryRebound(to: UInt16.self, capacity: elementCount) { wchars in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < elementCount && wchars[length] != 0 {
                        length += 1
                    }

                    // Copy raw code units
                    let rawCodeUnits = Array(UnsafeBufferPointer(start: wchars, count: length))
                    return File.Name(rawCodeUnits: rawCodeUnits)
                }
            }
        }
    #endif
}

// REMOVED: == (File.Name, String) operators
// Under strict policy, undecodable names would silently return false,
// encouraging string-like usage. Use String(name) explicitly when
// comparison is needed.

// MARK: - Zero-Copy Byte Access

extension File.Name {
    #if !os(Windows)
        /// Zero-copy access to raw UTF-8 bytes (POSIX only).
        ///
        /// Use this for performance-critical iteration paths.
        /// The bytes remain valid only for the duration of the closure.
        @inlinable
        public func withUnsafeUTF8Bytes<R>(
            _ body: (UnsafeBufferPointer<UInt8>) throws -> R
        ) rethrows -> R {
            try _rawBytes.withUnsafeBufferPointer(body)
        }
    #endif

    #if os(Windows)
        /// Zero-copy access to raw UTF-16 code units (Windows only).
        ///
        /// Use this for performance-critical iteration paths.
        /// The code units remain valid only for the duration of the closure.
        @inlinable
        public func withUnsafeCodeUnits<R>(
            _ body: (UnsafeBufferPointer<UInt16>) throws -> R
        ) rethrows -> R {
            try _rawCodeUnits.withUnsafeBufferPointer(body)
        }

        /// Access as UTF-8 bytes (allocates temporary buffer).
        ///
        /// For zero-copy access on Windows, use `withUnsafeCodeUnits` instead.
        /// This method is provided for cross-platform code that needs UTF-8.
        @inlinable
        public func withUTF8Bytes<R>(
            _ body: ([UInt8]) throws -> R
        ) rethrows -> R {
            var utf8Bytes: [UInt8] = []
            utf8Bytes.reserveCapacity(_rawCodeUnits.count * 3)  // worst case UTF-8 expansion
            for scalar in String(decoding: _rawCodeUnits, as: UTF16.self).unicodeScalars {
                UTF8.encode(scalar) { utf8Bytes.append($0) }
            }
            return try body(utf8Bytes)
        }
    #endif
}

// MARK: - Binary.Serializable

extension File.Name: Binary.Serializable {
    /// Serializes as UTF-8 bytes (cross-platform stable format).
    ///
    /// - POSIX: Zero-copy append of raw bytes
    /// - Windows: Allocates during serialization (UTF-16 → UTF-8 conversion)
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self, into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        #if os(Windows)
            for scalar in String(decoding: value._rawCodeUnits, as: UTF16.self).unicodeScalars {
                UTF8.encode(scalar) { buffer.append($0) }
            }
        #else
            buffer.append(contentsOf: value._rawBytes)
        #endif
    }
}
