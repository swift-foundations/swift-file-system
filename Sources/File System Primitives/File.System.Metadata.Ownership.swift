//
//  File.System.Metadata.Ownership.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Metadata {
    /// File ownership information.
    public struct Ownership: Sendable, Equatable {
        /// User ID of the owner.
        public var uid: UInt32

        /// Group ID of the owner.
        public var gid: UInt32

        public init(uid: UInt32, gid: UInt32) {
            self.uid = uid
            self.gid = gid
        }
    }
}

// MARK: - Error

extension File.System.Metadata.Ownership {
    /// Errors that can occur during ownership operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Ownership {
    /// Creates ownership by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Ownership.Error` on failure.
    public init(at path: File.Path) throws(File.System.Metadata.Ownership.Error) {
        #if os(Windows)
            // Windows doesn't expose uid/gid
            self.init(uid: 0, gid: 0)
        #else
            var statBuf = stat()
            guard stat(String(path), &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: path)
            }
            self.init(uid: statBuf.st_uid, gid: statBuf.st_gid)
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
        at path: File.Path
    ) throws(File.System.Metadata.Ownership.Error) {
        #if os(Windows)
            // Windows doesn't support chown - this is a no-op
            return
        #else
            guard chown(String(path), ownership.uid, ownership.gid) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        #endif
    }

    #if !os(Windows)
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .operationFailed(errno: errno, message: message)
            }
        }
    #endif
}

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Ownership.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let errno, let message):
            return "Operation failed: \(message) (errno=\(errno))"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Ownership: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.uid.bytes())
        buffer.append(contentsOf: value.gid.bytes())
    }
}
