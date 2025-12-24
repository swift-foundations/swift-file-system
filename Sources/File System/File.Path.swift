//
//  File.Path.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import SystemPackage

// MARK: - Appending (Convenience Methods)

extension File.Path {
    /// Appends a string component to this path.
    ///
    /// ```swift
    /// let path: File.Path = "/usr/local"
    /// let bin = path.appending("bin")  // "/usr/local/bin"
    /// ```
    @inlinable
    public func appending(_ string: String) -> File.Path {
        File.Path(self, appending: string)
    }

    /// Appends a validated component to this path.
    ///
    /// ```swift
    /// let component = try File.Path.Component("config.json")
    /// let full = basePath.appending(component)
    /// ```
    @inlinable
    public func appending(_ component: Component) -> File.Path {
        File.Path(self, appending: component)
    }

    /// Appends another path to this path.
    ///
    /// ```swift
    /// let base: File.Path = "/var/log"
    /// let sub: File.Path = "app/errors"
    /// let full = base.appending(sub)  // "/var/log/app/errors"
    /// ```
    @inlinable
    public func appending(_ other: File.Path) -> File.Path {
        File.Path(self, appending: other)
    }
}

extension File.Path {
    // MARK: - Components

    /// All path components as an array.
    @inlinable
    public var components: [Component] {
        _path.components.map { Component(__unchecked: $0) }
    }

    /// Number of path components.
    @inlinable
    public var count: Int {
        _path.components.count
    }

    // MARK: - Prefix/Relative

    /// Returns true if this path starts with the given prefix.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/usr/local/bin/swift"
    /// path.hasPrefix("/usr/local")  // true
    /// path.hasPrefix("/var")        // false
    /// ```
    @inlinable
    public func hasPrefix(_ other: File.Path) -> Bool {
        let selfComponents = Array(_path.components)
        let otherComponents = Array(other._path.components)

        guard otherComponents.count <= selfComponents.count else {
            return false
        }

        return zip(selfComponents, otherComponents).allSatisfy { $0 == $1 }
    }

    /// Returns the relative path from a base path, or nil if base is not a prefix.
    ///
    /// ## Example
    /// ```swift
    /// let path: File.Path = "/usr/local/bin/swift"
    /// let rel = path.relative(to: "/usr/local")  // "bin/swift"
    /// ```
    @inlinable
    public func relative(to base: File.Path) -> File.Path? {
        guard hasPrefix(base) else { return nil }

        let selfComponents = Array(_path.components)
        let baseCount = base._path.components.count

        guard baseCount < selfComponents.count else {
            // Same path
            return nil
        }

        var result = SystemPackage.FilePath()
        for component in selfComponents.dropFirst(baseCount) {
            result.append(component)
        }

        guard !result.isEmpty else { return nil }
        return File.Path(__unchecked: (), result)
    }
}

// MARK: - CustomStringConvertible

extension File.Path: CustomStringConvertible {
    @inlinable
    public var description: String {
        String(self)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Path: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Path(\(String(self).debugDescription))"
    }
}

// MARK: - File.Path.Component Protocol Conformances

extension File.Path.Component: CustomStringConvertible {
    @inlinable
    public var description: String {
        string
    }
}

extension File.Path.Component: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File.Path.Component(\(string.debugDescription))"
    }
}

extension File.Path.Component.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Component is empty"
        case .containsPathSeparator:
            return "Component contains path separator"
        case .containsControlCharacters:
            return "Component contains control characters"
        case .invalid:
            return "Component is invalid"
        }
    }
}

extension File.Path.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Path is empty"
        case .containsControlCharacters:
            return "Path contains control characters"
        }
    }
}
