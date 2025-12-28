//
//  File.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

// MARK: - Path Navigation

extension File {
    /// The parent directory as a file, or `nil` if this is a root path.
    public var parent: File? {
        path.parent.map(File.init)
    }

    /// The file name (last component of the path).
    public var name: String {
        path.lastComponent.map { String($0) } ?? ""
    }

    /// The file extension, or `nil` if there is none.
    public var `extension`: String? {
        path.extension
    }

    /// The filename without extension.
    public var stem: String? {
        path.stem
    }

    /// Returns a new file with the given component appended.
    ///
    /// - Parameter component: The component to append.
    /// - Returns: A new file with the appended path.
    public func appending(_ component: String) -> File {
        File(path.appending(component))
    }

    /// Appends a component to a file.
    ///
    /// - Parameters:
    ///   - lhs: The base file.
    ///   - rhs: The component to append.
    /// - Returns: A new file with the appended path.
    public static func / (lhs: File, rhs: String) -> File {
        lhs.appending(rhs)
    }
}

// MARK: - CustomStringConvertible

extension File: CustomStringConvertible {
    public var description: String {
        String(path)
    }
}

// MARK: - CustomDebugStringConvertible

extension File: CustomDebugStringConvertible {
    public var debugDescription: String {
        "File(\(String(path).debugDescription))"
    }
}

// MARK: - Link Operations

extension File {
    /// Access to link operations.
    ///
    /// Use this property to create symbolic links, hard links, or read link targets:
    /// ```swift
    /// // Create a symbolic link
    /// try file.link.symbolic(to: targetPath)
    ///
    /// // Create a hard link
    /// try file.link.hard(to: existingPath)
    ///
    /// // Read the target of a symlink
    /// let target = try file.link.target.path
    /// ```
    public var link: Link {
        Link(path: path)
    }

    /// Namespace for link operations on a file.
    public struct Link: Sendable {
        /// The path to operate on.
        public let path: File.Path

        /// Creates a Link instance.
        @usableFromInline
        internal init(path: File.Path) {
            self.path = path
        }

        // MARK: - Symbolic Links

        /// Creates a symbolic link at this path pointing to the target.
        ///
        /// - Parameter target: The path the symlink will point to.
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        public func symbolic(to target: File.Path) throws(File.System.Link.Symbolic.Error) {
            try File.System.Link.Symbolic.create(at: path, pointingTo: target)
        }

        /// Creates a symbolic link at this path pointing to the target.
        ///
        /// - Parameter target: The target file.
        /// - Throws: `File.System.Link.Symbolic.Error` on failure.
        public func symbolic(to target: File) throws(File.System.Link.Symbolic.Error) {
            try File.System.Link.Symbolic.create(at: path, pointingTo: target.path)
        }

        // MARK: - Hard Links

        /// Creates a hard link at this path to an existing file.
        ///
        /// Hard links share the same inode as the original file.
        ///
        /// - Parameter existing: The path to the existing file.
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        public func hard(to existing: File.Path) throws(File.System.Link.Hard.Error) {
            try File.System.Link.Hard.create(at: path, to: existing)
        }

        /// Creates a hard link at this path to an existing file.
        ///
        /// - Parameter existing: The existing file.
        /// - Throws: `File.System.Link.Hard.Error` on failure.
        public func hard(to existing: File) throws(File.System.Link.Hard.Error) {
            try File.System.Link.Hard.create(at: path, to: existing.path)
        }

        // MARK: - Read Target

        /// Namespace for reading symlink target.
        ///
        /// ## Usage
        /// ```swift
        /// let targetPath = try link.target.path
        /// let targetFile = try link.target.file
        /// ```
        public var target: Target { Target(link: self) }

        /// Target reading namespace.
        public struct Target: Sendable {
            let link: Link

            /// Reads the target of this symbolic link.
            ///
            /// - Returns: The target path that this symlink points to.
            /// - Throws: `File.System.Link.Read.Target.Error` on failure.
            public var path: File.Path {
                get throws(File.System.Link.Read.Target.Error) {
                    try File.System.Link.Read.Target.target(of: link.path)
                }
            }

            /// Reads the target of this symbolic link as a file.
            ///
            /// - Returns: The target file that this symlink points to.
            /// - Throws: `File.System.Link.Read.Target.Error` on failure.
            public var file: File {
                get throws(File.System.Link.Read.Target.Error) {
                    File(try File.System.Link.Read.Target.target(of: link.path))
                }
            }
        }
    }
}
