//
//  File.System.Parent.Check.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

public import Kernel

extension File.System {
    /// Parent directory operations.
    public enum Parent {}
}

extension File.System.Parent {
    /// Parent directory verification and creation.
    public enum Check {}
}

// MARK: - Verification

extension File.System.Parent.Check {
    /// Verifies that a parent directory exists and is accessible.
    ///
    /// - Parameters:
    ///   - path: The path to verify.
    ///   - createIntermediates: If `true`, attempts to create the directory if it doesn't exist.
    /// - Throws: `File.System.Parent.Check.Error` if verification fails.
    public static func verify(
        _ path: File.Path,
        createIntermediates: Bool
    ) throws(Self.Error) {
        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
        } catch {
            // Map Kernel.File.Stats.Error to Parent.Check.Error
            switch error {
            case .platform(let platformError):
                let code = platformError.code
                if code.isPermissionDenied {
                    throw .accessDenied(path: path)
                } else if code.isNotDirectory {
                    throw .notDirectory(path: path)
                } else if code.isNotFound {
                    if createIntermediates {
                        try createParent(at: path)
                        return
                    }
                    throw .missing(path: path)
                } else if code.isInvalidPath {
                    throw .invalidPath(path: path)
                } else if code.isNetworkNotFound {
                    throw .networkPathNotFound(path: path)
                } else {
                    throw .statFailed(path: path, operation: .stat, code: code)
                }

            case .handle:
                throw .statFailed(path: path, operation: .stat, code: .posix(0))
            }
        }

        // Check if it's a directory
        guard case .directory = stats.type else {
            throw .notDirectory(path: path)
        }
    }

    private static func createParent(at path: File.Path) throws(Self.Error) {
        do throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(
                at: path,
                createIntermediates: true
            )
        } catch {
            throw .creationFailed(path: path, underlying: error)
        }
    }
}

// MARK: - Operation

extension File.System.Parent.Check {
    /// The operation that was being performed when an error occurred.
    public enum Operation: Swift.String, Sendable {
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
        case statFailed(path: File.Path, operation: Operation, code: Error_Primitives.Error.Code)

        /// The path is malformed or contains invalid characters.
        case invalidPath(path: File.Path)

        /// A network path could not be found (Windows only).
        case networkPathNotFound(path: File.Path)

        // Creation failures (when createIntermediates = true)

        /// Failed to create the parent directory.
        case creationFailed(path: File.Path, underlying: File.System.Create.Directory.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Parent.Check.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        if case .missing = self { return true }
        if case .creationFailed(_, let e) = self, e.isParentNotFound { return true }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .accessDenied = self { return true }
        if case .creationFailed(_, let e) = self, e.isPermissionDenied { return true }
        return false
    }

    /// Returns `true` if a path component is not a directory.
    public var isNotDirectory: Bool {
        if case .notDirectory = self { return true }
        return false
    }

    /// Returns `true` if the path is invalid.
    public var isInvalidPath: Bool {
        if case .invalidPath = self { return true }
        return false
    }

    /// Returns `true` if a network path was not found (Windows).
    public var isNetworkPathNotFound: Bool {
        if case .networkPathNotFound = self { return true }
        return false
    }

    /// Returns `true` if parent directory creation failed.
    public var isCreationFailed: Bool {
        if case .creationFailed = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.System.Parent.Check.Error: CustomStringConvertible {
    public var description: Swift.String {
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
