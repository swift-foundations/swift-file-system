import Binary_Primitives
public import Kernel
import RFC_4648
public import Strings

extension File {

    public struct Name: Sendable, Equatable, Hashable {

        @usableFromInline
        package let rawBytes: [Path.Char]

        @usableFromInline
        internal init(rawBytes: [Path.Char]) {
            self.rawBytes = rawBytes
        }
    }
}

extension File.Name {

    @usableFromInline
    internal var isDotOrDotDot: Bool {
        rawBytes == [0x2E] || rawBytes == [0x2E, 0x2E]
    }

    @inlinable
    public var isHiddenByDotPrefix: Bool {
        rawBytes.first == 0x2E
    }
}

extension Swift.String {

    @inlinable
    public init?(_ fileName: File.Name) {
        guard let decoded = Self.strict(platformNative: fileName.rawBytes) else {
            return nil
        }
        self = decoded
    }

    @inlinable
    public init(lossy fileName: File.Name) {
        self = Self.lossy(platformNative: fileName.rawBytes)
    }

    @inlinable
    public init(validating fileName: File.Name) throws(File.Name.Decode.Error) {
        guard let decoded = Swift.String(fileName) else {
            throw File.Name.Decode.Error(name: fileName)
        }
        self = decoded
    }
}

extension File.Name: CustomStringConvertible {
    public var description: Swift.String {
        Swift.String(self) ?? Swift.String(lossy: self)
    }
}

extension File.Name: CustomDebugStringConvertible {

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

extension File.Name {

    @inlinable
    public init(from entry: Kernel.Directory.Entry) {
        self = entry.withName { view in
            let span = view.span
            var bytes: [Path_Primitives.Path.Char] = []
            bytes.reserveCapacity(span.count)
            for i in 0..<span.count {
                bytes.append(span[i])
            }
            return File.Name(rawBytes: bytes)
        }
    }
}

extension File.Name {

    @inlinable
    public func asPathComponent() throws(Paths.Path.Component.Error) -> File.Path.Component {
        try File.Path.Component(platformNative: rawBytes)
    }
}

extension File.Name {

    @inlinable
    public borrowing func withCodeUnits<R: ~Copyable, E: Swift.Error>(
        _ body: (Swift.Span<Path_Primitives.Path.Char>) throws(E) -> R
    ) throws(E) -> R {
        try body(rawBytes.span)
    }
}

extension File.Name {

    @inlinable
    public func withUTF8Bytes<R, E: Swift.Error>(
        _ body: ([UInt8]) throws(E) -> R
    ) throws(E) -> R {
        try body(rawBytes.utf8Bytes)
    }
}

extension File.Name {

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `posixBytes` exposed POSIX-specific byte storage and returned nil on Windows."
    )
    @inlinable
    public var posixBytes: [UInt8]? {
        #if os(Windows)
            return nil
        #else
            return rawBytes
        #endif
    }

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `windowsCodeUnits` exposed Windows-specific code-unit storage and returned nil on POSIX."
    )
    @inlinable
    public var windowsCodeUnits: [UInt16]? {
        #if os(Windows)
            return rawBytes
        #else
            return nil
        #endif
    }

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; bridge to UnsafeBufferPointer inside the closure if required."
    )
    @inlinable
    public func withUnsafeUTF8Bytes<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R
    ) throws(E) -> R? {
        #if os(Windows)
            return nil
        #else
            return try rawBytes.withUnsafeBufferPointer(body)
        #endif
    }

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; bridge to UnsafeBufferPointer inside the closure if required."
    )
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

    #if !os(Windows)

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

extension File.Name {

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `withBytes` was POSIX-only."
    )
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

    @available(
        *,
        deprecated,
        message:
            "Use `withCodeUnits { span in ... }` for cross-platform zero-copy access; `withBytes` was POSIX-only."
    )
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
}

extension File.Name: Binary.Serializable {

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
