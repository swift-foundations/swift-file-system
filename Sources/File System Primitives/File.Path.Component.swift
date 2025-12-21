//
//  File.Path.Component.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import INCITS_4_1986
import SystemPackage

extension File.Path {
    /// A single component of a file path.
    ///
    /// A component represents a single directory or file name within a path.
    /// For example, in `/usr/local/bin`, the components are `usr`, `local`, and `bin`.
    public struct Component: Hashable, Sendable {
        @usableFromInline
        package var _component: FilePath.Component

        /// Creates a component from a SystemPackage FilePath.Component.
        @usableFromInline
        package init(__unchecked component: FilePath.Component) {
            self._component = component
        }

        /// Creates a validated component from a string.
        ///
        /// - Parameter string: The component string.
        /// - Throws: `File.Path.Component.Error` if the string is invalid.
        @inlinable
        public init(_ string: String) throws(Error) {
            guard !string.isEmpty else {
                throw .empty
            }
            // Check BOTH separators on all platforms
            // POSIX forbids `/` in filenames, Windows forbids both `/` and `\`
            guard !string.contains("/") && !string.contains("\\") else {
                throw .containsPathSeparator
            }
            if string.utf8.contains(where: \.ascii.isControl) {
                throw .containsControlCharacters
            }
            guard let component = FilePath.Component(string) else {
                throw .invalid
            }
            self._component = component
        }
    }
}

// MARK: - Error

extension File.Path.Component {
    /// Errors that can occur during component construction.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The component string is empty.
        case empty
        /// The component contains a path separator.
        case containsPathSeparator
        /// The component contains control characters.
        case containsControlCharacters
        /// The component is invalid.
        case invalid
    }
}

// MARK: - Properties

extension File.Path.Component {
    /// The string representation of this component.
    @inlinable
    public var string: String {
        _component.string
    }

    /// The file extension, or `nil` if there is none.
    @inlinable
    public var `extension`: String? {
        _component.extension
    }

    /// The filename without extension.
    @inlinable
    public var stem: String? {
        _component.stem
    }

    /// The underlying SystemPackage FilePath.Component.
    @inlinable
    public var filePathComponent: FilePath.Component {
        _component
    }
}

// MARK: - ExpressibleByStringLiteral

extension File.Path.Component: ExpressibleByStringLiteral {
    /// Creates a component from a string literal.
    ///
    /// String literals are compile-time constants, so validation failures
    /// are programmer errors and will trigger a fatal error.
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid component literal: \(error)")
        }
    }
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
        /// - Throws: `Error` if the bytes are empty, contain forbidden characters,
        ///           or cannot be decoded as valid UTF-8.
        @inlinable
        public init<Bytes: Sequence>(utf8 bytes: Bytes) throws(Error)
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

            // Convert to String for FilePath.Component bridge
            guard let string = String._strictUTF8Decode(collected),
                let component = FilePath.Component(string)
            else {
                throw .invalid
            }
            self._component = component
        }

        /// Creates a validated component from an UnsafeBufferPointer of UTF-8 bytes.
        ///
        /// POSIX semantics: only rejects `/` (0x2F) and `NUL` (0x00).
        /// This overload avoids intermediate allocation when the buffer is already available.
        ///
        /// - Parameter buffer: The UTF-8 encoded component bytes.
        /// - Throws: `Error` if the buffer is empty, contains forbidden characters,
        ///           or cannot be decoded as valid UTF-8.
        @inlinable
        public init(utf8 buffer: UnsafeBufferPointer<UInt8>) throws(Error) {
            guard !buffer.isEmpty else { throw .empty }

            // POSIX: only / (0x2F) and NUL (0x00) are forbidden
            for byte in buffer {
                if byte == 0x2F || byte == 0x00 {
                    throw .containsPathSeparator
                }
            }

            // Convert to String for FilePath.Component bridge
            // Array allocation is unavoidable here because FilePath.Component requires String
            guard let string = String._strictUTF8Decode(Array(buffer)),
                let component = FilePath.Component(string)
            else {
                throw .invalid
            }
            self._component = component
        }
    }
#endif
