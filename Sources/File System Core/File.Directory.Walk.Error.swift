//
//  File.Directory.Walk.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Walk {
    /// Errors that can occur during directory walk operations.
    ///
    /// Directory walk uses recursive iteration through subdirectories.
    /// This error type provides semantic categories for common failure modes.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: Swift.String)
        case undecodableEntry(parent: File.Path, name: File.Name)
    }
}

// MARK: - Semantic Accessors

extension File.Directory.Walk.Error {
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

    /// Returns `true` if an entry could not be decoded.
    public var isUndecodableEntry: Bool {
        if case .undecodableEntry = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.Directory.Walk.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .walkFailed(let errno, let message):
            return "Walk failed: \(message) (errno=\(errno))"
        case .undecodableEntry(let parent, let name):
            return "Undecodable entry in \(parent): \(Swift.String(describing: name))"
        }
    }
}
