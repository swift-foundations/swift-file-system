//
//  File.System.Create.Directory.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System.Create.Directory {
    /// Errors that can occur during directory creation operations.
    ///
    /// This is a union of the kernel errors that directory creation can produce.
    /// Use semantic accessors like `isAlreadyExists` or `isPermissionDenied` for common checks,
    /// or match on the case for full error details.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Error from mkdir operation.
        case mkdir(Kernel.Directory.Create.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Create.Directory.Error {
    /// Returns `true` if the directory already exists.
    public var isAlreadyExists: Bool {
        if case .mkdir(let e) = self {
            return e == .exists
        }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .mkdir(let e) = self {
            return e == .permission
        }
        return false
    }

    /// Returns `true` if the parent directory was not found.
    public var isParentNotFound: Bool {
        if case .mkdir(let e) = self {
            return e == .notFound || e == .notDirectory
        }
        return false
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        if case .mkdir(let e) = self {
            return e == .readOnly
        }
        return false
    }

    /// Returns `true` if there's no space left on device.
    public var isNoSpace: Bool {
        if case .mkdir(let e) = self {
            return e == .noSpace
        }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.System.Create.Directory.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .mkdir(let error):
            return "Directory creation failed: \(error)"
        }
    }
}
