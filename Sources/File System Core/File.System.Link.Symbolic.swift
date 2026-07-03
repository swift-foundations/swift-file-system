//
//  File.System.Link.Symbolic.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System.Link {
    /// Symbolic link operations.
    public enum Symbolic {}
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Link.Symbolic {
    /// Errors that can occur during symbolic link operations.
    ///
    /// This wraps the kernel symlink error directly.
    /// Use semantic accessors like `isAlreadyExists` or `isPermissionDenied` for common checks,
    /// or match on the case for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from symlink operation.
        case symlink(Kernel.Link.Symbolic.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Link.Symbolic.Error {
    /// Returns `true` if the link already exists.
    public var isAlreadyExists: Bool {
        if case .symlink(let e) = self {
            return e == .exists
        }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .symlink(let e) = self {
            return e == .permission
        }
        return false
    }

    /// Returns `true` if the parent directory was not found.
    public var isParentNotFound: Bool {
        if case .symlink(let e) = self {
            return e == .notFound || e == .notDirectory
        }
        return false
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        if case .symlink(let e) = self {
            return e == .readOnly
        }
        return false
    }

    /// Returns `true` if there's no space left on device.
    public var isNoSpace: Bool {
        if case .symlink(let e) = self {
            return e == .noSpace
        }
        return false
    }
}

// MARK: - Core API

extension File.System.Link.Symbolic {
    /// Creates a symbolic link at the specified path pointing to target.
    ///
    /// - Parameters:
    ///   - path: The path where the symlink will be created.
    ///   - target: The path the symlink will point to.
    /// - Throws: `File.System.Link.Symbolic.Error` on failure.
    public static func create(
        at path: borrowing File.Path,
        pointingTo target: borrowing File.Path
    ) throws(Self.Error) {
        do throws(Kernel.Link.Symbolic.Error) {
            try Kernel.Link.Symbolic.create(target: target.kernelPath, at: path.kernelPath)
        } catch {
            throw .symlink(error)
        }
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Symbolic.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .symlink(let error):
            return "Symlink creation failed: \(error)"
        }
    }
}
