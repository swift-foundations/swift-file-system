//
//  File.Directory.Contents.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Contents {
    /// Errors that can occur when listing directory contents.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension File.Directory.Contents.Error: CustomStringConvertible {
    public var description: String {
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
