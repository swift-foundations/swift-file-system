//
//  File.System.Link.Read.Target.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel
import Strings

extension File.System.Link.Read {
    /// Read symbolic link target.
    public enum Target {}
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Link.Read.Target {
    /// Errors that can occur during reading link target operations.
    ///
    /// This is a union of the kernel errors that the readlink operation can produce.
    /// Use semantic accessors like `isNotFound` or `isNotASymlink` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from stat operation (checking if path is a symlink).
        case stat(Kernel.File.Stats.Error)
        /// Error from readlink operation.
        case readlink(Kernel.Link.Symbolic.Error)
        /// Path exists but is not a symbolic link.
        case notASymlink(File.Path)
        /// Invalid target path returned by readlink.
        case invalidTargetPath(Swift.String)
    }
}

// MARK: - Semantic Accessors

extension File.System.Link.Read.Target.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false
        case .readlink(let e):
            return e == .notFound
        default:
            return false
        }
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false
        case .readlink(let e):
            return e == .permission
        default:
            return false
        }
    }

    /// Returns `true` if the path is not a symbolic link.
    public var isNotASymlink: Bool {
        switch self {
        case .notASymlink:
            return true
        case .readlink(let e):
            return e == .notSymbolicLink
        default:
            return false
        }
    }
}

// MARK: - Core API

extension File.System.Link.Read.Target {
    /// Reads the target of a symbolic link.
    ///
    /// - Parameter path: The path to the symbolic link.
    /// - Returns: The target path that the symlink points to.
    /// - Throws: `File.System.Link.Read.Target.Error` on failure.
    public static func target(
        of path: borrowing File.Path
    ) throws(File.System.Link.Read.Target.Error) -> File.Path {
        // First check if it's a symlink using lstat (doesn't follow symlinks)
        let stats: Kernel.File.Stats
        do {
            stats = try Kernel.File.Stats.lget(path: path.kernelPath)
        } catch {
            throw .stat(error)
        }

        guard case .link = stats.type else {
            throw .notASymlink(copy path)
        }

        // Read the symlink target
        let targetString: Swift.String
        do throws(Kernel.Link.Symbolic.Error) {
            let kernelString = try Kernel.Link.Symbolic.readTarget(at: path.kernelPath)
            targetString = Swift.String(kernelString.view)
        } catch {
            throw .readlink(error)
        }

        guard let targetPath = try? File.Path(targetString) else {
            throw .invalidTargetPath(targetString)
        }
        return targetPath
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Read.Target.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"
        case .readlink(let error):
            return "Readlink failed: \(error)"
        case .notASymlink(let path):
            return "Not a symbolic link: \(path)"
        case .invalidTargetPath(let target):
            return "Invalid target path: \(target)"
        }
    }
}
