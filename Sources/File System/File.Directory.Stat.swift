//
//  File.Directory.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

import Kernel

// MARK: - Stat Namespace

extension File.Directory {
    /// Namespace for directory stat/metadata operations.
    ///
    /// Access via the `stat` property on a `File.Directory` instance:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// if dir.stat.exists {
    ///     let perms = try dir.stat.permissions
    ///     let empty = try dir.stat.isEmpty
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
    }
}

extension File.Directory.Stat {
    // MARK: - Existence Checks

    /// Returns `true` if the directory exists.
    @inlinable
    public var exists: Bool {
        File.System.Stat.exists(at: path)
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

    /// Returns directory metadata information.
    ///
    /// - Throws: `Kernel.File.Stats.Error` on failure.
    @inlinable
    public var info: File.System.Metadata.Info {
        get throws(Kernel.File.Stats.Error) {
            try File.System.Stat.info(at: path)
        }
    }

    /// Returns the directory permissions.
    ///
    /// - Throws: `Kernel.File.Stats.Error` on failure.
    @inlinable
    public var permissions: File.System.Metadata.Permissions {
        get throws(Kernel.File.Stats.Error) {
            try info.permissions
        }
    }

    /// Returns whether the directory is empty.
    ///
    /// - Returns: `true` if the directory contains no entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    @inlinable
    public var isEmpty: Bool {
        get throws(File.Directory.Contents.Error) {
            try File.Directory.Contents.list(at: File.Directory(path)).isEmpty
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to stat/metadata operations.
    ///
    /// Use this property to query directory metadata:
    /// ```swift
    /// if dir.stat.exists {
    ///     let perms = try dir.stat.permissions
    ///     let empty = try dir.stat.isEmpty
    /// }
    /// ```
    public var stat: Stat {
        Stat(path)
    }
}
