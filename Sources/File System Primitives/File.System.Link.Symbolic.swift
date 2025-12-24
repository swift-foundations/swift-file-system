//
//  File.System.Link.Symbolic.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Link {
    /// Symbolic link operations.
    public enum Symbolic {}
}

// MARK: - Error

extension File.System.Link.Symbolic {
    /// Errors that can occur during symbolic link operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case targetNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case linkFailed(errno: Int32, message: String)
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
        at path: File.Path,
        pointingTo target: File.Path
    ) throws(File.System.Link.Symbolic.Error) {
        #if os(Windows)
            try _createWindows(at: path, pointingTo: target)
        #else
            try _createPOSIX(at: path, pointingTo: target)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Link.Symbolic {
        internal static func _createPOSIX(
            at path: File.Path,
            pointingTo target: File.Path
        ) throws(File.System.Link.Symbolic.Error) {
            guard symlink(String(target), String(path)) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case EEXIST:
                return .alreadyExists(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOENT:
                return .targetNotFound(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .linkFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.System.Link.Symbolic {
        internal static func _createWindows(
            at path: File.Path,
            pointingTo target: File.Path
        ) throws(File.System.Link.Symbolic.Error) {
            // Check if target is a directory
            let targetAttrs = String(target).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            var flags: DWORD = _dword(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
            if targetAttrs != INVALID_FILE_ATTRIBUTES
                && (targetAttrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0
            {
                flags |= _dword(SYMBOLIC_LINK_FLAG_DIRECTORY)
            }

            let success = String(path).withCString(encodedAs: UTF16.self) { wlink in
                String(target).withCString(encodedAs: UTF16.self) { wtarget in
                    CreateSymbolicLinkW(wlink, wtarget, flags)
                }
            }

            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
        }

        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_ALREADY_EXISTS), _dword(ERROR_FILE_EXISTS):
                return .alreadyExists(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_PATH_NOT_FOUND):
                return .targetNotFound(path)
            default:
                return .linkFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Symbolic.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .targetNotFound(let path):
            return "Target not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "Link already exists: \(path)"
        case .linkFailed(let errno, let message):
            return "Symlink creation failed: \(message) (errno=\(errno))"
        }
    }
}
