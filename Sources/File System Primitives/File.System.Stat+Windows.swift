//
//  File.System.Stat+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    public import WinSDK
    @_spi(Internal) import StandardTime

    extension File.System.Stat {
        /// Gets file info using Windows APIs with explicit symlink-following behavior.
        ///
        /// - Parameters:
        ///   - path: The path to stat.
        ///   - followSymlinks: If `true`, follows symlinks to return target info (like POSIX `stat()`).
        ///                     If `false`, returns info about the symlink itself (like POSIX `lstat()`).
        /// - Returns: File metadata information.
        /// - Throws: `File.System.Stat.Error` on failure.
        @usableFromInline
        internal static func _infoWindows(
            at path: File.Path,
            followSymlinks: Bool
        ) throws(File.System.Stat.Error) -> File.System.Metadata.Info {
            // Determine flags for CreateFileW:
            // - FILE_FLAG_BACKUP_SEMANTICS: Required to open directories
            // - FILE_FLAG_OPEN_REPARSE_POINT: Opens the symlink itself (lstat behavior)
            //   Without this flag, CreateFileW follows symlinks (stat behavior)
            //
            // CRITICAL: For lstat semantics (!followSymlinks), ALWAYS include
            // FILE_FLAG_OPEN_REPARSE_POINT. Do NOT gate on attribute precheck,
            // as that can be misleading or race-prone.
            var flags = _mask(FILE_FLAG_BACKUP_SEMANTICS)
            if !followSymlinks {
                flags |= _mask(FILE_FLAG_OPEN_REPARSE_POINT)
            }

            // FILE_READ_ATTRIBUTES is the minimal access required for GetFileInformationByHandle.
            let handle = String(path).withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_READ_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    flags,
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { CloseHandle(handle) }

            // Get file info via handle
            var info = BY_HANDLE_FILE_INFORMATION()
            guard _ok(GetFileInformationByHandle(handle, &info)) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            // Determine file type
            // CRITICAL: For lstat (!followSymlinks), check reparse point FIRST.
            // A symlink to a directory has BOTH FILE_ATTRIBUTE_DIRECTORY and
            // FILE_ATTRIBUTE_REPARSE_POINT. If we check directory first, we'd
            // incorrectly classify symlinks as directories.
            let fileType: File.System.Metadata.Kind
            if !followSymlinks && (info.dwFileAttributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                // lstat semantics: check reparse tag to identify symlinks/junctions
                let reparseTag = _getReparseTag(handle: handle)
                if reparseTag == IO_REPARSE_TAG_SYMLINK || reparseTag == IO_REPARSE_TAG_MOUNT_POINT {
                    fileType = .symbolicLink
                } else if (info.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    // Other reparse points (cloud files) that are directories
                    fileType = .directory
                } else {
                    fileType = .regular
                }
            } else if (info.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                fileType = .directory
            } else {
                fileType = .regular
            }

            let size = Int64(info.nFileSizeHigh) << 32 | Int64(info.nFileSizeLow)
            let deviceId = UInt64(info.dwVolumeSerialNumber)
            let fileIndex = UInt64(info.nFileIndexHigh) << 32 | UInt64(info.nFileIndexLow)

            let timestamps = File.System.Metadata.Timestamps(
                accessTime: _fileTimeToUnix(info.ftLastAccessTime),
                modificationTime: _fileTimeToUnix(info.ftLastWriteTime),
                changeTime: _fileTimeToUnix(info.ftLastWriteTime),
                creationTime: _fileTimeToUnix(info.ftCreationTime)
            )

            // Windows doesn't have POSIX permissions, default to 644
            // Windows doesn't expose uid/gid
            return File.System.Metadata.Info(
                size: size,
                permissions: File.System.Metadata.Permissions.defaultFile,
                owner: File.System.Metadata.Ownership(uid: 0, gid: 0),
                timestamps: timestamps,
                type: fileType,
                inode: fileIndex,
                deviceId: deviceId,
                linkCount: UInt32(info.nNumberOfLinks)
            )
        }

        /// Gets file identity (volume serial + file index) for cycle detection.
        ///
        /// Uses GetFileInformationByHandle to get stable identity that works
        /// even for junctions and symlinks. Returns (0, 0) if unavailable.
        ///
        /// - Parameters:
        ///   - path: The path to get identity for.
        ///   - followSymlinks: If `true`, returns identity of symlink target.
        ///                     If `false`, returns identity of symlink itself.
        @usableFromInline
        internal static func _getFileIdentity(
            at path: File.Path,
            followSymlinks: Bool = true
        ) -> (deviceId: UInt64, fileIndex: UInt64) {
            // Check if it's a reparse point to decide on flags
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                return (0, 0)
            }

            let isReparsePoint = (attrs & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0

            // FILE_READ_ATTRIBUTES is the minimal access required for GetFileInformationByHandle.
            // FILE_FLAG_BACKUP_SEMANTICS is required to open directories.
            var flags = _mask(FILE_FLAG_BACKUP_SEMANTICS)
            if isReparsePoint && !followSymlinks {
                flags |= _mask(FILE_FLAG_OPEN_REPARSE_POINT)
            }

            let handle = String(path).withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_READ_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    flags,
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                return (0, 0)
            }
            defer { CloseHandle(handle) }

            var info = BY_HANDLE_FILE_INFORMATION()
            guard _ok(GetFileInformationByHandle(handle, &info)) else {
                return (0, 0)
            }

            let deviceId = UInt64(info.dwVolumeSerialNumber)
            let fileIndex = UInt64(info.nFileIndexHigh) << 32 | UInt64(info.nFileIndexLow)
            return (deviceId, fileIndex)
        }

        /// Checks if path exists using Windows APIs.
        @usableFromInline
        internal static func _existsWindows(at path: File.Path) -> Bool {
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }
            return attrs != INVALID_FILE_ATTRIBUTES
        }

        /// Checks if path is a symlink using Windows APIs.
        @usableFromInline
        internal static func _isSymlinkWindows(at path: File.Path) -> Bool {
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }
            guard attrs != INVALID_FILE_ATTRIBUTES else { return false }
            return (attrs & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0
        }

        /// Gets the reparse tag for an open handle.
        ///
        /// Uses DeviceIoControl with FSCTL_GET_REPARSE_POINT to read the reparse tag.
        /// Returns 0 if the tag cannot be read.
        @usableFromInline
        internal static func _getReparseTag(handle: HANDLE) -> DWORD {
            // We only need to read the first 4 bytes (ReparseTag)
            // Allocate a small buffer for the header
            let bufferSize = 8  // Minimum header: ReparseTag(4) + ReparseDataLength(2) + Reserved(2)
            let buffer = UnsafeMutableRawPointer.allocate(
                byteCount: bufferSize,
                alignment: MemoryLayout<DWORD>.alignment
            )
            defer { buffer.deallocate() }

            var bytesReturned: DWORD = 0
            let success = DeviceIoControl(
                handle,
                FSCTL_GET_REPARSE_POINT,
                nil,
                0,
                buffer,
                DWORD(bufferSize),
                &bytesReturned,
                nil
            )

            // Even if we get ERROR_MORE_DATA, we still have the tag in the first 4 bytes
            if success || GetLastError() == _dword(ERROR_MORE_DATA) {
                if bytesReturned >= 4 {
                    return buffer.load(as: DWORD.self)
                }
            }

            return 0
        }

        /// Converts Windows FILETIME to Time.
        ///
        /// FILETIME is 100-nanosecond intervals since 1601-01-01.
        @usableFromInline
        internal static func _fileTimeToUnix(_ ft: FILETIME) -> Time {
            // FILETIME is 100-nanosecond intervals since January 1, 1601
            // Unix epoch is January 1, 1970
            let intervals = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
            // Difference between 1601 and 1970 in 100ns
            let unixIntervals = intervals - 116_444_736_000_000_000
            let seconds = Int(unixIntervals / 10_000_000)
            let nanoseconds = Int((unixIntervals % 10_000_000) * 100)
            return Time(__unchecked: (), secondsSinceEpoch: seconds, nanoseconds: nanoseconds)
        }

        /// Maps Windows error to stat error.
        @usableFromInline
        internal static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            default:
                return .statFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif
