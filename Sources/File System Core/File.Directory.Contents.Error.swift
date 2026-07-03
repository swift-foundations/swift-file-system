//
//  File.Directory.Contents.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Contents {
    /// Errors that can occur when listing directory contents.
    ///
    /// Directory listing uses platform-specific APIs (opendir/readdir on POSIX,
    /// FindFirstFile on Windows). This error type provides semantic categories
    /// for common failure modes.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: Swift.String)
    }
}

// MARK: - Semantic Accessors

extension File.Directory.Contents.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        if case .pathNotFound = self { return true }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .permissionDenied = self { return true }
        return false
    }

    /// Returns `true` if the path is not a directory.
    public var isNotADirectory: Bool {
        if case .notADirectory = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.Directory.Contents.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"

        case .permissionDenied(let path):
            return "Permission denied: \(path)"

        case .notADirectory(let path):
            return "Not a directory: \(path)"

        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        }
    }
}
