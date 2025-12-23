//
//  File.Handle.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Handle {
    /// Errors that can occur during handle operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case isDirectory(File.Path)
        case invalidHandle
        case alreadyClosed
        case seekFailed(offset: Int64, origin: File.Handle.Seek.Origin, errno: Int32, message: String)
        case readFailed(errno: Int32, message: String)
        case writeFailed(errno: Int32, message: String)
        case closeFailed(errno: Int32, message: String)
        case openFailed(errno: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension File.Handle.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "File already exists: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .invalidHandle:
            return "Invalid file handle"
        case .alreadyClosed:
            return "Handle already closed"
        case .seekFailed(let offset, let origin, let errno, let message):
            return "Seek to \(offset) from \(origin) failed: \(message) (errno=\(errno))"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        case .writeFailed(let errno, let message):
            return "Write failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .openFailed(let errno, let message):
            return "Open failed: \(message) (errno=\(errno))"
        }
    }
}
