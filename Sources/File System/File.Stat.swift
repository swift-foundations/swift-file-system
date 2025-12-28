//
//  File.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Stat Namespace

extension File {
    /// Namespace for file stat/metadata operations.
    ///
    /// Access via the `stat` property on a `File` instance:
    /// ```swift
    /// let file: File = "/tmp/data.txt"
    ///
    /// if file.stat.exists {
    ///     let size = try file.stat.size
    ///     let perms = try file.stat.permissions
    /// }
    /// ```
    public struct Stat: Sendable {
        /// The path to stat.
        public let path: File.Path

        /// Creates a Stat instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - Existence Checks

        /// Returns `true` if the file exists.
        @inlinable
        public var exists: Bool {
            File.System.Stat.exists(at: path)
        }

        /// Returns `true` if the path is a regular file.
        @inlinable
        public var isFile: Bool {
            File.System.Stat.isFile(at: path)
        }

        /// Returns `true` if the path is a directory.
        @inlinable
        public var isDirectory: Bool {
            File.System.Stat.isDirectory(at: path)
        }

        /// Returns `true` if the path is a symbolic link.
        @inlinable
        public var isSymlink: Bool {
            File.System.Stat.isSymlink(at: path)
        }

        // MARK: - Metadata

        /// Returns file metadata information.
        ///
        /// - Throws: `File.System.Stat.Error` on failure.
        @inlinable
        public var info: File.System.Metadata.Info {
            get throws(File.System.Stat.Error) {
                try File.System.Stat.info(at: path)
            }
        }

        /// Returns the file size in bytes.
        ///
        /// - Throws: `File.System.Stat.Error` on failure.
        @inlinable
        public var size: Int64 {
            get throws(File.System.Stat.Error) {
                try info.size
            }
        }

        /// Returns the file permissions.
        ///
        /// - Throws: `File.System.Stat.Error` on failure.
        @inlinable
        public var permissions: File.System.Metadata.Permissions {
            get throws(File.System.Stat.Error) {
                try info.permissions
            }
        }

        /// Returns `true` if the file is empty (size is 0).
        ///
        /// - Throws: `File.System.Stat.Error` on failure.
        @inlinable
        public var isEmpty: Bool {
            get throws(File.System.Stat.Error) {
                try size == 0
            }
        }
    }
}

// MARK: - Instance Property

extension File {
    /// Access to stat/metadata operations.
    ///
    /// Use this property to query file metadata:
    /// ```swift
    /// if file.stat.exists {
    ///     let size = try file.stat.size
    ///     let perms = try file.stat.permissions
    /// }
    /// ```
    public var stat: Stat {
        Stat(path)
    }
}
