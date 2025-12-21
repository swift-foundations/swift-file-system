//
//  File.Directory.Walk.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Walk {
    /// Errors that can occur during directory walk operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: String)
        case undecodableEntry(parent: File.Path, name: File.Name)
    }
}

// MARK: - CustomStringConvertible

extension File.Directory.Walk.Error: CustomStringConvertible {
    public var description: String {
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
            return "Undecodable entry in \(parent): \(name.debugDescription)"
        }
    }
}
