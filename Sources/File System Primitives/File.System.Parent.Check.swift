//
//  File.System.Parent.Check.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.System {
    /// Parent directory operations.
    public enum Parent {}
}

extension File.System.Parent {
    /// Parent directory verification and creation.
    public enum Check {}
}

// MARK: - Operation

extension File.System.Parent.Check {
    /// The operation that was being performed when an error occurred.
    public enum Operation: String, Sendable {
        case stat = "stat(parent)"
        case getFileAttributes = "GetFileAttributesW(parent)"
    }
}

// MARK: - Error

extension File.System.Parent.Check {
    /// Errors that can occur during parent directory verification.
    public enum Error: Swift.Error, Equatable, Sendable {
        // Verification failures

        /// Access to the parent directory was denied.
        case accessDenied(path: File.Path)

        /// A component of the path exists but is not a directory.
        case notDirectory(path: File.Path)

        /// The parent directory does not exist.
        case missing(path: File.Path)

        /// A system call failed with an unclassified error code.
        case statFailed(path: File.Path, operation: Operation, code: File.System.Error.Code)

        /// The path is malformed or contains invalid characters.
        case invalidPath(path: File.Path)

        /// A network path could not be found (Windows only).
        case networkPathNotFound(path: File.Path)

        // Creation failures (when createIntermediates = true)

        /// Failed to create the parent directory.
        case creationFailed(path: File.Path, underlying: File.System.Create.Directory.Error)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Parent.Check.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .accessDenied(let path):
            return "Access denied to parent directory: \(path)"
        case .notDirectory(let path):
            return "Path component is not a directory: \(path)"
        case .missing(let path):
            return "Parent directory not found: \(path)"
        case .statFailed(let path, let operation, let code):
            return "\(operation.rawValue) failed for \(path): \(code)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .networkPathNotFound(let path):
            return "Network path not found: \(path)"
        case .creationFailed(let path, let underlying):
            return "Failed to create parent directory \(path): \(underlying)"
        }
    }
}
