//
//  File.Path.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Environment
import Kernel
public import Paths
import Strings

extension File {
    /// A file system path.
    ///
    /// `File.Path` is a typealias for `Paths.Path`, providing a consistent naming
    /// convention within the swift-file-system namespace.
    ///
    /// Path validation happens at construction time. A `File.Path` is guaranteed
    /// to be non-empty and free of control characters.
    ///
    /// ## Example
    /// ```swift
    /// let path = try File.Path("/usr/local/bin")
    /// let child = path / "swift"
    /// print(String(child))  // "/usr/local/bin/swift"
    /// ```
    public typealias Path = Paths.Path
}

// MARK: - Common Extensions

extension File.Path {
    /// Package non-throwing initializer for trusted Path sources.
    ///
    /// Use this for Path values derived from valid File.Path operations
    /// where we know the result cannot be empty or contain control characters.
    @usableFromInline
    package init(__unchecked: Void, _ path: Paths.Path) {
        self = path
    }

    /// Package non-throwing initializer for trusted string sources.
    @usableFromInline
    package init(__unchecked: Void, _ string: Swift.String) {
        self = Paths.Path(stringLiteral: string)
    }

    /// The parent directory, falling back to self for root paths.
    ///
    /// Internal use for write implementations that need a valid parent path.
    @usableFromInline
    package var parentOrSelf: Paths.Path {
        parent ?? self
    }
}

// MARK: - POSIX Resolution

#if !os(Windows)

    extension File.Path {
        /// Internal initializer from a null-terminated C string pointer.
        ///
        /// Use this for paths from trusted sources like kernel APIs (fts, readdir)
        /// where the path is guaranteed to be valid. Avoids intermediate String allocation.
        ///
        /// - Parameter cString: A pointer to a null-terminated C string.
        /// - Precondition: The pointer must be valid and null-terminated.
        @usableFromInline
        internal init(cString: UnsafePointer<CChar>) {
            let string = unsafe Swift.String(cString: cString)
            self = Paths.Path(stringLiteral: string)
        }
    }

#endif
