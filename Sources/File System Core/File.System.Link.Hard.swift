//
//  File.System.Link.Hard.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System.Link {
    /// Hard link operations.
    public enum Hard {}
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Link.Hard {
    /// Errors that can occur during hard link operations.
    ///
    /// This wraps the kernel link error directly.
    /// Use semantic accessors like `isAlreadyExists` or `isPermissionDenied` for common checks,
    /// or match on the case for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from link operation.
        case link(Kernel.Link.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Link.Hard.Error {
    /// Returns `true` if the source was not found.
    public var isSourceNotFound: Bool {
        if case .link(let e) = self {
            return e == .notFound
        }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .link(let e) = self {
            return e == .permission
        }
        return false
    }

    /// Returns `true` if the link already exists.
    public var isAlreadyExists: Bool {
        if case .link(let e) = self {
            return e == .exists
        }
        return false
    }

    /// Returns `true` if the operation crossed filesystem boundaries.
    public var isCrossDevice: Bool {
        if case .link(let e) = self {
            return e == .crossDevice
        }
        return false
    }

    /// Returns `true` if the source is a directory (cannot hard link directories).
    public var isDirectory: Bool {
        if case .link(let e) = self {
            return e == .isDirectory
        }
        return false
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        if case .link(let e) = self {
            return e == .readOnly
        }
        return false
    }

    /// Returns `true` if there are too many links to the file.
    public var isTooManyLinks: Bool {
        if case .link(let e) = self {
            return e == .tooManyLinks
        }
        return false
    }
}

// MARK: - Core API

extension File.System.Link.Hard {
    /// Creates a hard link at the specified path to an existing file.
    ///
    /// - Parameters:
    ///   - path: The path where the hard link will be created.
    ///   - existing: The path to the existing file.
    /// - Throws: `File.System.Link.Hard.Error` on failure.
    public static func create(
        at path: borrowing File.Path,
        to existing: borrowing File.Path
    ) throws(File.System.Link.Hard.Error) {
        do throws(Kernel.Link.Error) {
            try Kernel.Link.create(at: path.kernelPath, to: existing.kernelPath)
        } catch {
            throw .link(error)
        }
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Hard.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .link(let error):
            return "Hard link creation failed: \(error)"
        }
    }
}
