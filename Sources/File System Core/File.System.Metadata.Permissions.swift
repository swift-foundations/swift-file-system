//
//  File.System.Metadata.Permissions.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary_Primitives
public import Kernel

extension File.System.Metadata {
    /// POSIX file permissions.
    public struct Permissions: OptionSet, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

extension File.System.Metadata.Permissions {
    // Owner permissions
    public static let ownerRead = Self(rawValue: 0o400)
    public static let ownerWrite = Self(rawValue: 0o200)
    public static let ownerExecute = Self(rawValue: 0o100)

    // Group permissions
    public static let groupRead = Self(rawValue: 0o040)
    public static let groupWrite = Self(rawValue: 0o020)
    public static let groupExecute = Self(rawValue: 0o010)

    // Other permissions
    public static let otherRead = Self(rawValue: 0o004)
    public static let otherWrite = Self(rawValue: 0o002)
    public static let otherExecute = Self(rawValue: 0o001)

    // Special bits
    public static let setuid = Self(rawValue: 0o4000)
    public static let setgid = Self(rawValue: 0o2000)
    public static let sticky = Self(rawValue: 0o1000)

    // Common combinations
    public static let ownerAll: Self = [.ownerRead, .ownerWrite, .ownerExecute]
    public static let groupAll: Self = [.groupRead, .groupWrite, .groupExecute]
    public static let otherAll: Self = [.otherRead, .otherWrite, .otherExecute]

    /// Default file permissions (644).
    public static let defaultFile: Self = [
        .ownerRead, .ownerWrite, .groupRead, .otherRead,
    ]

    /// Default directory permissions (755).
    public static let defaultDirectory: Self = [
        .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
    ]

    /// Executable file permissions (755).
    public static let executable: Self = [
        .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
    ]
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Metadata.Permissions {
    /// Errors that can occur during permission operations.
    ///
    /// This is a union of the kernel errors that permission operations can produce.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from stat operation (reading permissions).
        case stat(Kernel.File.Stats.Error)
        /// Error from chmod operation (setting permissions).
        case chmod(Kernel.File.Attributes.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Metadata.Permissions.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .chmod(let e):
            if case .path(.notFound) = e { return true }
            return false
        }
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .chmod(let e):
            if case .permission(.denied) = e { return true }
            if case .permission(.notPermitted) = e { return true }
            return false
        }
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        switch self {
        case .chmod(let e):
            if case .permission(.readOnlyFilesystem) = e { return true }
            return false

        default:
            return false
        }
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Permissions {
    /// Creates permissions by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Permissions.Error` on failure.
    public init(at path: borrowing File.Path) throws(Self.Error) {
        // Both legs read through Stats: the Windows L2 synthesizes
        // POSIX-shaped permissions (readonly bit → write mask, directory
        // attribute → execute bits), so the placeholder .defaultFile
        // short-circuit is retired.
        do throws(Kernel.File.Stats.Error) {
            let stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
            self.init(rawValue: stats.permissions.rawValue)
        } catch {
            throw .stat(error)
        }
    }
}

// MARK: - Set API

extension File.System.Metadata.Permissions {
    /// Sets the permissions of a file.
    ///
    /// - Parameters:
    ///   - permissions: The permissions to set.
    ///   - path: The path to the file.
    /// - Throws: `File.System.Metadata.Permissions.Error` on failure.
    public static func set(
        _ permissions: Self,
        at path: borrowing File.Path
    ) throws(Self.Error) {
        #if os(Windows)
            // Windows doesn't have POSIX permissions - this is a no-op
            return
        #else
            do throws(Kernel.File.Attributes.Error) {
                try path.withKernelPath { kernelPath throws(Kernel.File.Attributes.Error) in
                    try Kernel.File.Attributes.set(
                        Kernel.File.Permissions(rawValue: permissions.rawValue),
                        at: kernelPath
                    )
                }
            } catch {
                throw .chmod(error)
            }
        #endif
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Permissions.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"

        case .chmod(let error):
            return "Chmod failed: \(error)"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Permissions: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}
