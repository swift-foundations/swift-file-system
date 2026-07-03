//
//  File.System.Metadata.Ownership.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary_Primitives
public import Kernel

extension File.System.Metadata {
    /// File ownership information.
    public struct Ownership: Sendable, Equatable {
        /// User ID of the owner.
        public var uid: Kernel.User.ID

        /// Group ID of the owner.
        public var gid: Kernel.Group.ID

        public init(uid: Kernel.User.ID, gid: Kernel.Group.ID) {
            self.uid = uid
            self.gid = gid
        }
    }
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Metadata.Ownership {
    /// Errors that can occur during ownership operations.
    ///
    /// This is a union of the kernel errors that ownership operations can produce.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from stat operation (reading ownership).
        case stat(Kernel.File.Stats.Error)
        /// Error from chown operation (setting ownership).
        case chown(Kernel.File.Chown.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Metadata.Ownership.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false
        case .chown(let e):
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
        case .chown(let e):
            if case .permission(.denied) = e { return true }
            if case .permission(.notPermitted) = e { return true }
            return false
        }
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        switch self {
        case .chown(let e):
            if case .permission(.readOnlyFilesystem) = e { return true }
            return false
        default:
            return false
        }
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Ownership {
    /// Creates ownership by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Ownership.Error` on failure.
    public init(at path: borrowing File.Path) throws(File.System.Metadata.Ownership.Error) {
        #if os(Windows)
            // Windows doesn't expose uid/gid, but the path must still exist —
            // route through the same Stats call the POSIX branch uses below
            // (mirrors the Windows-side Stats read in
            // File.System.Metadata.Permissions.init(at:)) so a nonexistent
            // path throws like POSIX instead of silently synthesizing (0, 0).
            do {
                _ = try Kernel.File.Stats.get(path: path.kernelPath)
            } catch {
                throw .stat(error)
            }
            self.init(uid: 0, gid: 0)
        #else
            do {
                let stats = try Kernel.File.Stats.get(path: path.kernelPath)
                self.init(uid: stats.uid, gid: stats.gid)
            } catch {
                throw .stat(error)
            }
        #endif
    }
}

// MARK: - Set API

extension File.System.Metadata.Ownership {
    /// Sets the ownership of a file.
    ///
    /// Requires appropriate privileges (usually root).
    ///
    /// - Parameters:
    ///   - ownership: The ownership to set.
    ///   - path: The path to the file.
    /// - Throws: `File.System.Metadata.Ownership.Error` on failure.
    public static func set(
        _ ownership: Self,
        at path: borrowing File.Path
    ) throws(File.System.Metadata.Ownership.Error) {
        // Windows has no chown syscall; Kernel.File.Chown is the single
        // cross-platform entry point and owns the no-op/conditional
        // semantics for platforms without real ownership — this L3 domain
        // layer no longer special-cases Windows here.
        do throws(Kernel.File.Chown.Error) {
            try Kernel.File.Chown.chown(
                path: path.kernelPath,
                uid: ownership.uid,
                gid: ownership.gid
            )
        } catch {
            throw .chown(error)
        }
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Ownership.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"
        case .chown(let error):
            return "Chown failed: \(error)"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Ownership: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.uid.underlying.bytes())
        buffer.append(contentsOf: value.gid.underlying.bytes())
    }
}
