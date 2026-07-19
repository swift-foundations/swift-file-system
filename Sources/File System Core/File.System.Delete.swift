//
//  File.System.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System {
    /// Namespace for file deletion operations.
    public enum Delete {}
}

// MARK: - Options

extension File.System.Delete {
    /// Options for delete operations.
    public struct Options: Sendable {
        public init() {}
    }
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Delete {
    /// Errors that can occur during delete operations.
    ///
    /// This is a union of the kernel errors that the delete operation can produce.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from stat operation (checking if path exists and its type).
        case stat(Kernel.File.Stats.Error)
        /// Error from unlink operation (deleting a file).
        case unlink(Kernel.File.Delete.Error)
        /// Error from rmdir operation (deleting an empty directory).
        case rmdir(Kernel.Directory.Remove.Error)
        /// Error from directory iteration (during recursive delete).
        case directory(Kernel.Directory.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Delete.Error {
    /// Returns `true` if the error indicates the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .unlink(let e):
            if case .notFound = e { return true }
            return false

        case .rmdir(let e):
            return e == .notFound

        case .directory(let e):
            return e == .notFound
        }
    }

    /// Returns `true` if the error indicates permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .unlink(let e):
            if case .permission = e { return true }
            return false

        case .rmdir(let e):
            return e == .permission

        case .directory(let e):
            return e == .permission
        }
    }

    /// Returns `true` if the error indicates the path is a directory (use recursive option).
    public var isDirectory: Bool {
        switch self {
        case .unlink(let e):
            if case .isDirectory = e { return true }
            return false

        default:
            return false
        }
    }

    /// Returns `true` if the error indicates a directory is not empty.
    public var isDirectoryNotEmpty: Bool {
        switch self {
        case .rmdir(let e):
            return e == .notEmpty

        default:
            return false
        }
    }
}

// MARK: - Core API

extension File.System.Delete {
    /// Deletes a file or directory at the specified path.
    ///
    /// - Parameters:
    ///   - path: The path to delete.
    ///   - recursive: If `true`, deletes directory contents recursively.
    /// - Throws: `File.System.Delete.Error` on failure.
    public static func delete(
        at path: borrowing File.Path,
        recursive: Bool = false
    ) throws(Error) {
        // Classify the deletion root with lstat (never following symlinks):
        // a symlink whose target is a directory must never be traversed
        // into (it would delete the target's contents instead of the
        // link), and a dangling symlink must still be deletable even
        // though its target does not exist.
        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try lstat(path)
        } catch {
            throw .stat(error)
        }

        if case .link = stats.type {
            // The path itself is a symlink. Always unlink the link, never
            // the target — regardless of `recursive`, regardless of what
            // (or whether) it points at.
            try unlink(at: path)
            return
        }

        let isDirectory = stats.type == .directory

        if isDirectory {
            if recursive {
                try deleteRecursive(at: path)
            } else {
                // Try to remove empty directory
                try rmdir(at: path)
            }
        } else {
            // Remove file
            try unlink(at: path)
        }
    }

    /// Stats a path without following symlinks, using Kernel.File.Stats.
    @usableFromInline
    internal static func lstat(_ path: File.Path) throws(Kernel.File.Stats.Error) -> Kernel.File.Stats {
        try Kernel.File.Stats.lget(path: path.kernelPath)
    }

    /// Removes a file using Kernel.File.Delete.
    @usableFromInline
    internal static func unlink(at path: File.Path) throws(Error) {
        do throws(Kernel.File.Delete.Error) {
            try Kernel.File.Delete.delete(path.kernelPath)
        } catch {
            throw .unlink(error)
        }
    }

    /// Removes an empty directory using Kernel.Directory.Remove.
    @usableFromInline
    internal static func rmdir(at path: File.Path) throws(Error) {
        do throws(Kernel.Directory.Remove.Error) {
            try Kernel.Directory.Remove.remove(path.kernelPath)
        } catch {
            throw .rmdir(error)
        }
    }

    /// Recursively deletes a directory and all its contents.
    @usableFromInline
    internal static func deleteRecursive(
        at path: File.Path
    ) throws(Error) {
        // Open directory
        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try Kernel.Directory.open(at: path.kernelPath)
        } catch {
            throw .directory(error)
        }
        defer { stream.close() }

        // Iterate through entries
        while true {
            let entry: Kernel.Directory.Entry?
            do throws(Kernel.Directory.Error) {
                entry = try stream.next()
            } catch {
                throw .directory(error)
            }

            guard let entry else {
                break  // End of directory
            }

            // Skip . and ..
            if entry.isDotOrDotDot {
                continue
            }

            // Unified via File.Name — owns the platform-conditional decode
            let component: File.Path.Component
            do throws(Paths.Path.Component.Error) {
                component = try File.Name(from: entry).asPathComponent()
            } catch {
                // Skip entries with invalid path components (should be rare)
                continue
            }
            let childPath = path / component

            // Check if directory or file
            if case .directory = entry.type {
                try deleteRecursive(at: childPath)
            } else {
                try unlink(at: childPath)
            }
        }

        // Now delete the empty directory
        try rmdir(at: path)
    }
}
