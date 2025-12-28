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
    import CFileSystemShims
#elseif canImport(Musl)
    import Musl
    import CFileSystemShims
#elseif os(Windows)
    internal import WinSDK
#endif

extension File.Directory {
    /// List directory contents.
    public enum Contents {}
}

// MARK: - Core API

extension File.Directory.Contents {
    /// Lists the contents of a directory.
    ///
    /// - Parameter directory: The directory to list.
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public static func list(
        at directory: File.Directory
    ) throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
        #if os(Windows)
            return try _listWindows(at: directory)
        #else
            return try _listPOSIX(at: directory.path)
        #endif
    }
}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.Directory.Contents {
        internal static func _listPOSIX(
            at path: File.Path
        ) throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(String(path), &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            // Open directory
            guard let dir = opendir(String(path)) else {
                throw _mapErrno(errno, path: path)
            }
            defer { closedir(dir) }

            var entries: [File.Directory.Entry] = []

            // Set errno before loop to detect errors
            errno = 0
            while let entry = readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    errno = 0  // Reset for next iteration
                    continue
                }

                // Determine type from d_type (path computed lazily via Entry.path())
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
                        // Construct path on-demand for lstat only
                        if let entryPath = File.Directory.Entry(
                            name: name,
                            parent: path,
                            type: .other
                        ).pathIfValid {
                            var entryStat = stat()
                            if lstat(String(entryPath), &entryStat) == 0 {
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
                        } else {
                            // Cannot lstat undecodable path - mark as other
                            entryType = .other
                        }
                    }
                #endif

                entries.append(File.Directory.Entry(name: name, parent: path, type: entryType))

                // Reset errno for next iteration
                errno = 0
            }

            // Check for error after loop
            if errno != 0 {
                throw _mapErrno(errno, path: path)
            }

            return entries
        }

        static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
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
        package static func _listWindows(
            at directory: File.Directory
        ) throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
            // Verify it's a directory
            let path = directory.path
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
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
            let searchPath = String(path) + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { FindClose(handle) }

            repeat {
                let name = File.Name(windowsDirectoryEntryName: findData.cFileName)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Determine type (path computed lazily via Entry.path())
                // IMPORTANT: Check reparse point FIRST because directory symlinks have
                // both FILE_ATTRIBUTE_DIRECTORY and FILE_ATTRIBUTE_REPARSE_POINT set.
                // Checking directory first would incorrectly classify symlinks as directories.
                let entryType: File.Directory.Entry.Kind
                if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                    // Reparse points (symlinks, junctions, mount points) classified as symlinks
                    // to prevent incorrect recursion during directory walks
                    entryType = .symbolicLink
                } else if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    entryType = .directory
                } else {
                    entryType = .file
                }

                entries.append(File.Directory.Entry(name: name, parent: path, type: entryType))
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
