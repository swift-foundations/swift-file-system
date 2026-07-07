//
//  File.Name.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import Binary_Primitives
public import Kernel
import RFC_4648
public import Strings

extension File {
    /// A directory entry name that preserves the raw filesystem encoding.
    ///
    /// ## Strict Encoding Policy
    /// `File.Name` stores the raw platform-native code units (`Path.Char`) exactly
    /// as returned by the filesystem — `UInt8` (UTF-8) on POSIX, `UInt16` (UTF-16)
    /// on Windows. This ensures:
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
        /// Raw filesystem-native code units (NUL-terminator excluded).
        @usableFromInline
        package let rawBytes: [Path.Char]

        @usableFromInline
        internal init(rawBytes: [Path.Char]) {
            self.rawBytes = rawBytes
        }
    }
}

// MARK: - Semantic Predicates

extension File.Name {
    /// True if this name is "." or ".." (dot entries to skip during iteration).
    @usableFromInline
    internal var isDotOrDotDot: Bool {
        rawBytes == [0x2E] || rawBytes == [0x2E, 0x2E]
    }

    /// True if this name starts with '.' (hidden file convention on Unix-like systems).
    @inlinable
    public var isHiddenByDotPrefix: Bool {
        rawBytes.first == 0x2E
    }
}

// MARK: - String Conversion (Extension Inits)

extension Swift.String {
    /// Creates a string from a file name using strict UTF-8/UTF-16 decoding.
    ///
    /// Returns `nil` if the raw data contains invalid encoding.
    ///
    /// - POSIX: Returns `nil` if raw bytes are not valid UTF-8
    /// - Windows: Returns `nil` if raw code units contain invalid UTF-16, such as lone surrogates
    @inlinable
    public init?(_ fileName: File.Name) {
        guard let decoded = Self.strict(platformNative: fileName.rawBytes) else {
            return nil
        }
        self = decoded
    }

    /// Creates a string from a file name using lossy decoding.
    ///
    /// Invalid sequences are replaced with the Unicode replacement character (U+FFFD).
    ///
    /// Delegates to ``Strings/Swift/String/lossy(platformNative:)`` (unified
    /// L3 entry point in swift-strings) which dispatches POSIX → UTF-8 vs
    /// Windows → UTF-16 lossy decoding.
    ///
    /// - Warning: Paths containing replacement characters cannot be used to re-open files.
    @inlinable
    public init(lossy fileName: File.Name) {
        self = Self.lossy(platformNative: fileName.rawBytes)
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
        guard let decoded = Swift.String(fileName) else {
            throw File.Name.Decode.Error(name: fileName)
        }
        self = decoded
    }
}

// MARK: - CustomStringConvertible

extension File.Name: CustomStringConvertible {
    public var description: Swift.String {
        Swift.String(self) ?? Swift.String(lossy: self)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Name: CustomDebugStringConvertible {
    /// A debug description showing raw bytes/code units when decoding fails.
    public var debugDescription: Swift.String {
        if let str = Swift.String(self) {
            return "File.Name(\"\(str)\")"
        } else {
            let hex = rawBytes.platformNativeHex(uppercase: true)
            #if os(Windows)
                return "File.Name(invalidUTF16: [\(hex)])"
            #else
                return "File.Name(invalidUTF8: [\(hex)])"
            #endif
        }
    }
}

// MARK: - Initialization from Kernel.Directory.Entry

extension File.Name {
    /// Creates a `File.Name` from a Kernel directory entry.
    ///
    /// Copies the entry's NUL-excluded code units from `entry.name.span`.
    /// No platform conditional is needed here: `Path.Char` already resolves to
    /// the correct element type for the current platform.
    @inlinable
    public init(from entry: Kernel.Directory.Entry) {
        let span = entry.name.span
        var bytes: [Path_Primitives.Path.Char] = []
        bytes.reserveCapacity(span.count)
        for i in 0..<span.count {
            bytes.append(span[i])
        }
        self.rawBytes = bytes
    }
}

// MARK: - Path.Component Adoption

extension File.Name {
    /// Converts this name into a validated `File.Path.Component`.
    ///
    /// Unified L3 bridge from filesystem-native name bytes to a `Paths.Path.Component`.
    /// Consumers never need a platform conditional — the dispatch lives in
    /// ``Paths/Path/Component/init(platformNative:)``.
    ///
    /// - Throws: `Paths.Path.Component.Error.invalidUTF8` if the name cannot be
    ///   decoded on Windows, or any `Path.Component.Error` raised by validation.
    @inlinable
    public func asPathComponent() throws(Paths.Path.Component.Error) -> File.Path.Component {
        try File.Path.Component(platformNative: rawBytes)
    }
}

// REMOVED: == (File.Name, String) operators
// Under strict policy, undecodable names would silently return false,
// encouraging string-like usage. Use String(name) explicitly when
// comparison is needed.

// MARK: - Code-Unit Access

extension File.Name {
    // substrate: code-unit (Path_Primitives.Path.Char = String_Primitives.String.Char)
    /// Scoped zero-copy access to the name's platform-native code units.
    ///
    /// The body receives a borrowed `Span` over the raw code units (NUL-
    /// excluded). `Path.Char` is `UInt8` on POSIX (UTF-8) and `UInt16` on
    /// Windows (UTF-16); callers that need cross-platform decoding should
    /// route through `Swift.String(_:)` / `Swift.String(lossy:)` /
    /// `Swift.String(validating:)` rather than inspect the code units
    /// directly.
    ///
    /// Replaces the deprecated platform-conditional accessors (`posixBytes`,
    /// `windowsCodeUnits`, `withUnsafeUTF8Bytes`, `withUnsafeCodeUnits`,
    /// `withBytes`, the Windows-shaped `withCodeUnits<R>` / `<R, E>` returning
    /// `R?`).
    @inlinable
    public borrowing func withCodeUnits<R: ~Copyable, E: Swift.Error>(
        _ body: (Swift.Span<Path_Primitives.Path.Char>) throws(E) -> R
    ) throws(E) -> R {
        try body(rawBytes.span)
    }
}

// MARK: - UTF-8 Wire Format

extension File.Name {
    // substrate: wire-format helper (UTF-8 canonical cross-platform serialization)
    /// Access as UTF-8 bytes (may allocate for Windows encoding).
    ///
    /// UTF-8 is the canonical cross-platform wire format for filename
    /// serialization (matches `Binary.Serializable` output and JSON / IPC
    /// payloads). For zero-copy code-unit access in the platform-
    /// native encoding, use `withCodeUnits` instead.
    ///
    /// Delegates to ``Strings/Array/utf8Bytes`` (unified L3 entry point in
    /// swift-strings) which dispatches POSIX → zero-cost identity vs
    /// Windows → scalar-loop UTF-16-to-UTF-8 transcoding.
    @inlinable
    public func withUTF8Bytes<R, E: Swift.Error>(
        _ body: ([UInt8]) throws(E) -> R
    ) throws(E) -> R {
        try body(rawBytes.utf8Bytes)
    }
}

// MARK: - Deprecated Byte-Domain Accessors (Phase A parallel API)

extension File.Name {
    // substrate: codec (POSIX UTF-8 code units) — deprecated public surface; replaced by `withCodeUnits`
    /// Returns the raw POSIX bytes if available.
    ///
    /// - Returns: The raw bytes if this name uses POSIX encoding, `nil` otherwise.
    @available(*, deprecated, message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `posixBytes` exposed POSIX-specific byte storage and returned nil on Windows.")
    @inlinable
    public var posixBytes: [UInt8]? {
        #if os(Windows)
            return nil
        #else
            return rawBytes
        #endif
    }

    // substrate: codec (Windows UTF-16 code units) — deprecated public surface; replaced by `withCodeUnits`
    /// Returns the raw Windows code units if available.
    ///
    /// - Returns: The raw code units if this name uses Windows encoding, `nil` otherwise.
    @available(
        *,
        deprecated,
        message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `windowsCodeUnits` exposed Windows-specific code-unit storage and returned nil on POSIX."
    )
    @inlinable
    public var windowsCodeUnits: [UInt16]? {
        #if os(Windows)
            return rawBytes
        #else
            return nil
        #endif
    }

    // substrate: stdlib boundary (UnsafeBufferPointer<UInt8> callback) — deprecated public surface
    /// Zero-copy access to raw UTF-8 bytes (POSIX encoding only).
    ///
    /// - Returns: `nil` if the name uses Windows encoding.
    @available(*, deprecated, message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; bridge to UnsafeBufferPointer inside the closure if required.")
    @inlinable
    public func withUnsafeUTF8Bytes<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R
    ) throws(E) -> R? {
        #if os(Windows)
            return nil
        #else
            return unsafe try rawBytes.withUnsafeBufferPointer(body)
        #endif
    }

    // substrate: codec (POSIX UTF-8 code units via Span) — deprecated public surface
    /// Zero-copy access to raw UTF-8 bytes as a Span (POSIX encoding only).
    ///
    /// - Returns: `nil` if the name uses Windows encoding.
    @available(*, deprecated, message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `withBytes` was POSIX-only.")
    @inlinable
    public func withBytes<R>(
        _ body: (Swift.Span<UInt8>) -> R
    ) -> R? {
        #if os(Windows)
            return nil
        #else
            return body(rawBytes.span)
        #endif
    }

    // substrate: codec (POSIX UTF-8 code units via Span) — deprecated public surface
    /// Zero-copy access to raw UTF-8 bytes as a Span (POSIX encoding only).
    ///
    /// Throwing variant for closures that may fail.
    ///
    /// - Returns: `nil` if the name uses Windows encoding.
    @available(*, deprecated, message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `withBytes` was POSIX-only.")
    @inlinable
    public func withBytes<R, E: Swift.Error>(
        _ body: (Swift.Span<UInt8>) throws(E) -> R
    ) throws(E) -> R? {
        #if os(Windows)
            return nil
        #else
            return try body(rawBytes.span)
        #endif
    }

    // substrate: stdlib boundary (UnsafeBufferPointer<UInt16> callback) — deprecated public surface
    /// Zero-copy access to raw UTF-16 code units (Windows encoding only).
    ///
    /// - Returns: `nil` if the name uses POSIX encoding.
    @available(*, deprecated, message: "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; bridge to UnsafeBufferPointer inside the closure if required.")
    @inlinable
    public func withUnsafeCodeUnits<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<UInt16>) throws(E) -> R
    ) throws(E) -> R? {
        #if os(Windows)
            return unsafe try rawBytes.withUnsafeBufferPointer(body)
        #else
            return nil
        #endif
    }

    // The Windows-shaped `withCodeUnits<R>(_ body: (Swift.Span<UInt16>) -> R) -> R?`
    // and its throwing variant are platform-gated to non-Windows only. On
    // Windows, `Path.Char == UInt16`, so the deprecated `(Swift.Span<UInt16>) -> R?`
    // signature collides with the new `(Swift.Span<Path.Char>) -> R` accessor. On
    // POSIX, `Path.Char == UInt8`, the two signatures are distinct, and the
    // deprecation marker fires cleanly for any consumer that explicitly
    // typed the closure parameter `Swift.Span<UInt16>` (the prior Windows-only
    // access path). Windows consumers that previously relied on the
    // optional return must drop the optional unwrap when migrating to the
    // new `withCodeUnits`.
    #if !os(Windows)
        // substrate: codec (Windows UTF-16 code units via Span) — deprecated public surface; POSIX-gated to avoid Windows signature collision with the new `withCodeUnits`
        /// Zero-copy access to raw UTF-16 code units as a Span (Windows encoding only).
        ///
        /// - Returns: `nil` if the name uses POSIX encoding.
        @available(
            *,
            deprecated,
            message:
                "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; the Windows-shaped `withCodeUnits` returning `R?` is superseded by the platform-agnostic accessor returning `R`."
        )
        @inlinable
        public func withCodeUnits<R>(
            _ body: (Swift.Span<UInt16>) -> R
        ) -> R? {
            return nil
        }

        // substrate: codec (Windows UTF-16 code units via Span) — deprecated public surface; POSIX-gated to avoid Windows signature collision with the new `withCodeUnits`
        /// Zero-copy access to raw UTF-16 code units as a Span (Windows encoding only).
        ///
        /// Throwing variant for closures that may fail.
        ///
        /// - Returns: `nil` if the name uses POSIX encoding.
        @available(
            *,
            deprecated,
            message:
                "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; the Windows-shaped `withCodeUnits` returning `R?` is superseded by the platform-agnostic accessor returning `R`."
        )
        @inlinable
        public func withCodeUnits<R, E: Swift.Error>(
            _ body: (Swift.Span<UInt16>) throws(E) -> R
        ) throws(E) -> R? {
            return nil
        }
    #endif
}

// MARK: - Binary.Serializable

extension File.Name: Binary.Serializable {
    /// Serializes as UTF-8 bytes (cross-platform stable format).
    ///
    /// Delegates to ``Strings/Array/appendUTF8(into:)`` (unified L3 entry
    /// point in swift-strings, buffer-append shape) which dispatches POSIX
    /// → zero-cost append-contents-of vs Windows → scalar-loop
    /// UTF-16-to-UTF-8 transcoding with per-byte append. swift-strings'
    /// `appendUTF8(into:)` is `Buffer.Element == UInt8`-constrained (stays
    /// UInt8 per W2 discrimination — internal stdlib-idiom utility); the
    /// intermediate `[UInt8]` buffer bridges through the BSLI cross-domain
    /// `append(contentsOf:) where S.Element == UInt8` extension on
    /// `RangeReplaceableCollection where Element: Byte.Protocol`.
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        var tmp: [UInt8] = []
        value.rawBytes.appendUTF8(into: &tmp)
        buffer.append(contentsOf: tmp)
    }
}
