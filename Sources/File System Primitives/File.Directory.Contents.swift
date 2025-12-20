//
//  File.Directory.Contents.swift
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

extension File.Directory {
    /// List directory contents.
    public enum Contents {}
}

// MARK: - Error

extension File.Directory.Contents {
    /// Errors that can occur when listing directory contents.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.Directory.Contents {
    /// Lists the contents of a directory.
    ///
    /// - Parameter path: The path to the directory.
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public static func list(at path: File.Path) throws(Error) -> [File.Directory.Entry] {
        #if os(Windows)
            return try _listWindows(at: path)
        #else
            return try _listPOSIX(at: path)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.Directory.Contents {
        internal static func _listPOSIX(at path: File.Path) throws(Error) -> [File.Directory.Entry]
        {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            // Open directory
            guard let dir = opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }
            defer { closedir(dir) }

            var entries: [File.Directory.Entry] = []

            while let entry = readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and ..
                if name == "." || name == ".." {
                    continue
                }

                // Build full path using lossy string (File.Path is String-backed)
                let entryPath = File.Path(path, appending: String(lossy: name))

                // Determine type
                let entryType: File.Directory.Entry.Kind
                #if canImport(Darwin)
                    switch Int32(entry.pointee.d_type) {
                    case DT_REG:
                        entryType = .file
                    case DT_DIR:
                        entryType = .directory
                    case DT_LNK:
                        entryType = .symbolicLink
                    default:
                        entryType = .other
                    }
                #else
                    // Linux/Glibc - trust d_type when available, fallback to lstat only for DT_UNKNOWN
                    // This avoids N syscalls for N files, massive perf improvement for large directories
                    let dtype = Int32(entry.pointee.d_type)
                    if dtype != Int32(DT_UNKNOWN) {
                        switch dtype {
                        case Int32(DT_REG):
                            entryType = .file
                        case Int32(DT_DIR):
                            entryType = .directory
                        case Int32(DT_LNK):
                            entryType = .symbolicLink
                        default:
                            entryType = .other
                        }
                    } else {
                        // Filesystem doesn't support d_type (e.g., some network filesystems)
                        // Fall back to lstat for this entry
                        var entryStat = stat()
                        if lstat(entryPath.string, &entryStat) == 0 {
                            switch entryStat.st_mode & S_IFMT {
                            case S_IFREG:
                                entryType = .file
                            case S_IFDIR:
                                entryType = .directory
                            case S_IFLNK:
                                entryType = .symbolicLink
                            default:
                                entryType = .other
                            }
                        } else {
                            entryType = .other
                        }
                    }
                #endif

                entries.append(File.Directory.Entry(name: name, path: entryPath, type: entryType))
            }

            return entries
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOTDIR:
                return .notADirectory(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .readFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.Directory.Contents {
        internal static func _listWindows(
            at path: File.Path
        ) throws(Error) -> [File.Directory.Entry] {
            // Verify it's a directory
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                throw .pathNotFound(path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 else {
                throw .notADirectory(path)
            }

            var entries: [File.Directory.Entry] = []
            var findData = WIN32_FIND_DATAW()
            let searchPath = path.string + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { FindClose(handle) }

            repeat {
                let name = File.Name(windowsDirectoryEntryName: findData.cFileName)

                // Skip . and ..
                if name == "." || name == ".." {
                    continue
                }

                // Build full path using lossy string (File.Path is String-backed)
                let entryPath = File.Path(path, appending: String(lossy: name))

                // Determine type
                let entryType: File.Directory.Entry.Kind
                if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    entryType = .directory
                } else if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                    entryType = .symbolicLink
                } else {
                    entryType = .file
                }

                entries.append(File.Directory.Entry(name: name, path: entryPath, type: entryType))
            } while _ok(FindNextFileW(handle, &findData))

            let lastError = GetLastError()
            if lastError != _dword(ERROR_NO_MORE_FILES) {
                throw _mapWindowsError(lastError, path: path)
            }

            return entries
        }

        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            default:
                return .readFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.Directory.Contents.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        }
    }
}
