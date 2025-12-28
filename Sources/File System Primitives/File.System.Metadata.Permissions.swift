//
//  File.System.Metadata.Permissions.swift
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
    internal import WinSDK
#endif

extension File.System.Metadata {
    /// POSIX file permissions.
    public struct Permissions: OptionSet, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        // Owner permissions
        public static let ownerRead = Permissions(rawValue: 0o400)
        public static let ownerWrite = Permissions(rawValue: 0o200)
        public static let ownerExecute = Permissions(rawValue: 0o100)

        // Group permissions
        public static let groupRead = Permissions(rawValue: 0o040)
        public static let groupWrite = Permissions(rawValue: 0o020)
        public static let groupExecute = Permissions(rawValue: 0o010)

        // Other permissions
        public static let otherRead = Permissions(rawValue: 0o004)
        public static let otherWrite = Permissions(rawValue: 0o002)
        public static let otherExecute = Permissions(rawValue: 0o001)

        // Special bits
        public static let setuid = Permissions(rawValue: 0o4000)
        public static let setgid = Permissions(rawValue: 0o2000)
        public static let sticky = Permissions(rawValue: 0o1000)

        // Common combinations
        public static let ownerAll: Permissions = [.ownerRead, .ownerWrite, .ownerExecute]
        public static let groupAll: Permissions = [.groupRead, .groupWrite, .groupExecute]
        public static let otherAll: Permissions = [.otherRead, .otherWrite, .otherExecute]

        /// Default file permissions (644).
        public static let defaultFile: Permissions = [
            .ownerRead, .ownerWrite, .groupRead, .otherRead,
        ]

        /// Default directory permissions (755).
        public static let defaultDirectory: Permissions = [
            .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
        ]

        /// Executable file permissions (755).
        public static let executable: Permissions = [
            .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
        ]
    }
}

// MARK: - Error

extension File.System.Metadata.Permissions {
    /// Errors that can occur during permission operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Permissions {
    /// Creates permissions by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Permissions.Error` on failure.
    public init(at path: File.Path) throws(File.System.Metadata.Permissions.Error) {
        #if os(Windows)
            // Windows doesn't have POSIX permissions
            self = .defaultFile
        #else
            var statBuf = stat()
            guard stat(String(path), &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: path)
            }
            self.init(rawValue: UInt16(statBuf.st_mode & 0o7777))
        #endif
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
        at path: File.Path
    ) throws(File.System.Metadata.Permissions.Error) {
        #if os(Windows)
            // Windows doesn't have POSIX permissions - this is a no-op
            return
        #else
            guard chmod(String(path), mode_t(permissions.rawValue)) == 0 else {
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

extension File.System.Metadata.Permissions.Error: CustomStringConvertible {
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

extension File.System.Metadata.Permissions: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}
