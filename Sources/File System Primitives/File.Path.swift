//
//  File.Path.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Binary
public import INCITS_4_1986
import SystemPackage

extension File {
    /// A file system path.
    ///
    /// `File.Path` wraps `SystemPackage.FilePath` with a consistent API
    /// that follows swift-file-system naming conventions.
    ///
    /// Path validation happens at construction time. A `File.Path` is guaranteed
    /// to be non-empty and free of control characters.
    ///
    /// ## Example
    /// ```swift
    /// let path = try File.Path.init("/usr/local/bin")
    /// let child = path / "swift"
    /// print(child.string)  // "/usr/local/bin/swift"
    /// ```
    public struct Path: Hashable, Sendable {
        @usableFromInline
        package var _path: FilePath

        /// Creates a validated path from a string.
        ///
        /// - Parameter string: The path string to validate and wrap.
        /// - Throws: `File.Path.Error` if the path is empty or contains control characters.
        @inlinable
        public init(_ string: String) throws(File.Path.Error) {
            guard !string.isEmpty else {
                throw .empty
            }

            // Check for control characters before FilePath conversion
            // (FilePath may truncate at NUL, so we validate the original string)
            if string.utf8.contains(where: \.ascii.isControl) {
                throw .containsControlCharacters
            }

            self._path = FilePath(string)
        }

        /// Creates a path from a SystemPackage FilePath.
        ///
        /// - Parameter filePath: The FilePath to wrap.
        /// - Throws: `File.Path.Error.empty` if the path is empty.
        @inlinable
        public init(_ filePath: FilePath) throws(File.Path.Error) {
            guard !filePath.isEmpty else {
                throw .empty
            }
            self._path = filePath
        }

        /// Package non-throwing initializer for trusted string sources.
        @usableFromInline
        package init(__unchecked: Void, _ string: String) {
            self._path = FilePath(string)
        }

        /// Package non-throwing initializer for trusted FilePath sources.
        ///
        /// Use this for FilePath values derived from valid File.Path operations
        /// where we know the result cannot be empty or contain control characters.
        @usableFromInline
        package init(__unchecked: Void, _ filePath: FilePath) {
            self._path = filePath
        }
    }
}

// MARK: - Navigation

extension File.Path {
    /// The parent directory of this path, or `nil` if this is a root path.
    @inlinable
    public var parent: File.Path? {
        let parent = _path.removingLastComponent()
        guard parent != _path else { return nil }
        return File.Path(__unchecked: (), parent)
    }
}

// MARK: - Appending (Canonical Inits)

extension File.Path {
    /// Creates a new path by appending a component to a base path.
    @inlinable
    public init(_ base: File.Path, appending component: Component) {
        var copy = base._path
        copy.append(component._component)
        self.init(__unchecked: (), copy)
    }

    /// Creates a new path by appending another path to a base path.
    @inlinable
    public init(_ base: File.Path, appending other: File.Path) {
        var copy = base._path
        for component in other._path.components {
            copy.append(component)
        }
        self.init(__unchecked: (), copy)
    }

    /// Creates a new path by appending a string component to a base path.
    @inlinable
    public init(_ base: File.Path, appending string: String) {
        var copy = base._path
        copy.append(string)
        self.init(__unchecked: (), copy)
    }
}

// MARK: - Introspection

extension File.Path {
    /// The last component of the path, or `nil` if the path is empty.
    @inlinable
    public var lastComponent: Component? {
        _path.lastComponent.map { Component(__unchecked: $0) }
    }

    /// The file extension, or `nil` if there is none.
    @inlinable
    public var `extension`: String? {
        _path.extension
    }

    /// The filename without extension.
    @inlinable
    public var stem: String? {
        _path.stem
    }

    /// Whether this is an absolute path.
    @inlinable
    public var isAbsolute: Bool {
        _path.isAbsolute
    }

    /// Whether this is a relative path.
    @inlinable
    public var isRelative: Bool {
        !_path.isAbsolute
    }

    /// Whether the path is empty.
    @inlinable
    public var isEmpty: Bool {
        _path.isEmpty
    }
}

// MARK: - Conversion

extension File.Path {
    /// The string representation of this path.
    @available(*, deprecated, message: "Use String(path) instead")
    @inlinable
    public var string: String {
        _path.string
    }

    /// The underlying SystemPackage FilePath.
    ///
    /// Use this for interoperability with SystemPackage APIs.
    @inlinable
    public var filePath: FilePath {
        _path
    }
}

// MARK: - ExpressibleByStringLiteral

extension File.Path: ExpressibleByStringLiteral {
    /// Creates a path from a string literal.
    ///
    /// String literals are compile-time constants, so validation failures
    /// are programmer errors and will trigger a fatal error.
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path literal: \(error)")
        }
    }
}

// MARK: - Operators

extension File.Path {
    /// Appends a string component to a path.
    ///
    /// ```swift
    /// let path: File.Path = "/usr/local"
    /// let bin = path / "bin"  // "/usr/local/bin"
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: String) -> File.Path {
        File.Path(lhs, appending: rhs)
    }

    /// Appends a validated component to a path.
    ///
    /// ```swift
    /// let component = try File.Path.Component("config.json")
    /// let path = basePath / component
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: Component) -> File.Path {
        File.Path(lhs, appending: rhs)
    }

    /// Appends a path to a path.
    ///
    /// ```swift
    /// let base: File.Path = "/var/log"
    /// let sub: File.Path = "app/errors"
    /// let full = base / sub  // "/var/log/app/errors"
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: File.Path) -> File.Path {
        File.Path(lhs, appending: rhs)
    }
}

// MARK: - Binary.Serializable

extension File.Path: Binary.Serializable {
    /// Serializes the path as UTF-8 bytes.
    ///
    /// This enables `String(path)` via `StringProtocol.init<T: Binary.Serializable>(_:)`.
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: path._path.string.utf8)
    }
}
