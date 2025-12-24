//
//  File.System.Link.Read.Target.swift
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

extension File.System.Link.Read {
    /// Read symbolic link target.
    public enum Target {}
}

// MARK: - Error

extension File.System.Link.Read.Target {
    /// Errors that can occur during reading link target operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case notASymlink(File.Path)
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Link.Read.Target {
    /// Reads the target of a symbolic link.
    ///
    /// - Parameter path: The path to the symbolic link.
    /// - Returns: The target path that the symlink points to.
    /// - Throws: `File.System.Link.Read.Target.Error` on failure.
    public static func target(
        of path: File.Path
    ) throws(File.System.Link.Read.Target.Error) -> File.Path {
        #if os(Windows)
            return try _targetWindows(of: path)
        #else
            return try _targetPOSIX(of: path)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Link.Read.Target {
        internal static func _targetPOSIX(
            of path: File.Path
        ) throws(File.System.Link.Read.Target.Error) -> File.Path {
            // First check if it's a symlink
            var statBuf = stat()
            guard lstat(String(path), &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFLNK else {
                throw .notASymlink(path)
            }

            // Read the link target
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
            let length = readlink(String(path), &buffer, Int(PATH_MAX))

            guard length >= 0 else {
                throw _mapErrno(errno, path: path)
            }

            let targetString = String(
                decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )

            guard let targetPath = try? File.Path(targetString) else {
                throw .readFailed(errno: 0, message: "Invalid target path: \(targetString)")
            }

            return targetPath
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EINVAL:
                return .notASymlink(path)
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
    extension File.System.Link.Read.Target {
        internal static func _targetWindows(
            of path: File.Path
        ) throws(File.System.Link.Read.Target.Error) -> File.Path {
            // Check if it's a reparse point (symlink)
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                // Map the actual Windows error, not just assume pathNotFound
                throw _mapWindowsError(GetLastError(), path: path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 else {
                throw .notASymlink(path)
            }

            // Open the file to read the reparse point data
            // Note: We need FILE_FLAG_OPEN_REPARSE_POINT to open the symlink itself,
            // not its target. FILE_READ_ATTRIBUTES is the minimal access required for
            // DeviceIoControl with FSCTL_GET_REPARSE_POINT.
            // FILE_FLAG_BACKUP_SEMANTICS is required to open directory symlinks.
            let handle = String(path).withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_READ_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS) | _mask(FILE_FLAG_OPEN_REPARSE_POINT),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { CloseHandle(handle) }

            // Read the reparse point data using DeviceIoControl
            // MAXIMUM_REPARSE_DATA_BUFFER_SIZE is 16384 bytes
            let bufferSize = 16384
            let buffer = UnsafeMutableRawPointer.allocate(
                byteCount: bufferSize,
                alignment: MemoryLayout<UInt32>.alignment
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

            guard success else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            // Parse the REPARSE_DATA_BUFFER structure
            // Layout:
            //   DWORD  ReparseTag        (offset 0)
            //   USHORT ReparseDataLength (offset 4)
            //   USHORT Reserved          (offset 6)
            //   Then either SymbolicLinkReparseBuffer or MountPointReparseBuffer

            // Bounds check: minimum header size is 8 bytes
            // Layout: ReparseTag (4) + ReparseDataLength (2) + Reserved (2)
            let minimumHeaderSize: DWORD = 8
            guard bytesReturned >= minimumHeaderSize else {
                throw .readFailed(errno: 0, message: "Reparse buffer too small: \(bytesReturned) bytes")
            }

            let reparseTag = buffer.load(as: DWORD.self)
            let reparseDataLength = buffer.load(fromByteOffset: 4, as: UInt16.self)

            // Validate ReparseDataLength: the data portion must fit within the returned buffer
            // Total buffer = 8-byte header + reparseDataLength
            guard DWORD(reparseDataLength) + 8 <= bytesReturned else {
                throw .readFailed(errno: 0, message: "ReparseDataLength (\(reparseDataLength)) exceeds buffer: \(bytesReturned) bytes")
            }

            // Verify it's a symlink or mount point
            guard reparseTag == IO_REPARSE_TAG_SYMLINK || reparseTag == IO_REPARSE_TAG_MOUNT_POINT
            else {
                throw .notASymlink(path)
            }

            // For both symlinks and mount points, the buffer layout after the header is:
            //   USHORT SubstituteNameOffset (offset 8)
            //   USHORT SubstituteNameLength (offset 10)
            //   USHORT PrintNameOffset      (offset 12)
            //   USHORT PrintNameLength      (offset 14)
            //   [ULONG Flags]               (offset 16, symlink only)
            //   WCHAR  PathBuffer[]         (offset 16 for mount point, 20 for symlink)

            // Bounds check: need at least 16 bytes to read offset/length fields
            let minimumFieldsSize: DWORD = 16
            guard bytesReturned >= minimumFieldsSize else {
                throw .readFailed(errno: 0, message: "Reparse buffer too small for fields: \(bytesReturned) bytes")
            }

            let printNameOffset = buffer.load(fromByteOffset: 12, as: UInt16.self)
            let printNameLength = buffer.load(fromByteOffset: 14, as: UInt16.self)

            // PathBuffer starts after the header
            let pathBufferOffset: Int
            if reparseTag == IO_REPARSE_TAG_SYMLINK {
                pathBufferOffset = 20  // After Flags field
            } else {
                pathBufferOffset = 16  // No Flags field for mount points
            }

            // Bounds check: ensure we have at least the header before PathBuffer
            guard bytesReturned >= DWORD(pathBufferOffset) else {
                throw .readFailed(errno: 0, message: "Reparse buffer too small for path buffer: \(bytesReturned) < \(pathBufferOffset) bytes")
            }

            // Validate offset and length are multiples of 2 (UTF-16 alignment)
            guard printNameOffset % 2 == 0 else {
                throw .readFailed(errno: 0, message: "Invalid PrintNameOffset: \(printNameOffset) is not even")
            }
            guard printNameLength % 2 == 0 else {
                throw .readFailed(errno: 0, message: "Invalid PrintNameLength: \(printNameLength) is not even")
            }

            // Calculate where the PrintName is in the PathBuffer
            let printNameStart = pathBufferOffset + Int(printNameOffset)
            let printNameEnd = printNameStart + Int(printNameLength)
            let printNameCharCount = Int(printNameLength) / MemoryLayout<UInt16>.size

            // Extract the target path string
            // Note: The path data in the reparse buffer is NOT null-terminated,
            // so we must use the length fields and decode the exact byte range.
            var targetString: String
            if printNameCharCount > 0 {
                // Bounds check: ensure PrintName data is within returned buffer
                guard printNameEnd <= Int(bytesReturned) else {
                    throw .readFailed(errno: 0, message: "PrintName extends beyond buffer: end \(printNameEnd) > size \(bytesReturned)")
                }

                let printNamePtr = buffer.advanced(by: printNameStart)
                    .assumingMemoryBound(to: UInt16.self)
                let utf16Buffer = UnsafeBufferPointer(
                    start: printNamePtr,
                    count: printNameCharCount
                )
                targetString = String(decoding: utf16Buffer, as: UTF16.self)
            } else {
                // Fall back to SubstituteName if PrintName is empty
                let substituteNameOffset = buffer.load(fromByteOffset: 8, as: UInt16.self)
                let substituteNameLength = buffer.load(fromByteOffset: 10, as: UInt16.self)

                // Validate offset and length are multiples of 2 (UTF-16 alignment)
                guard substituteNameOffset % 2 == 0 else {
                    throw .readFailed(errno: 0, message: "Invalid SubstituteNameOffset: \(substituteNameOffset) is not even")
                }
                guard substituteNameLength % 2 == 0 else {
                    throw .readFailed(errno: 0, message: "Invalid SubstituteNameLength: \(substituteNameLength) is not even")
                }

                let substituteNameStart = pathBufferOffset + Int(substituteNameOffset)
                let substituteNameEnd = substituteNameStart + Int(substituteNameLength)
                let substituteNameCharCount = Int(substituteNameLength) / MemoryLayout<UInt16>.size

                if substituteNameCharCount > 0 {
                    // Bounds check: ensure SubstituteName data is within returned buffer
                    guard substituteNameEnd <= Int(bytesReturned) else {
                        throw .readFailed(errno: 0, message: "SubstituteName extends beyond buffer: end \(substituteNameEnd) > size \(bytesReturned)")
                    }

                    let substituteNamePtr = buffer.advanced(by: substituteNameStart)
                        .assumingMemoryBound(to: UInt16.self)
                    let utf16Buffer = UnsafeBufferPointer(
                        start: substituteNamePtr,
                        count: substituteNameCharCount
                    )
                    targetString = String(decoding: utf16Buffer, as: UTF16.self)

                    // SubstituteName may have \??\ prefix, remove it
                    if targetString.hasPrefix("\\??\\") {
                        targetString = String(targetString.dropFirst(4))
                    }
                } else {
                    throw .readFailed(errno: 0, message: "Empty reparse point target")
                }
            }

            guard let targetPath = try? File.Path(targetString) else {
                throw .readFailed(errno: 0, message: "Invalid target path: \(targetString)")
            }

            return targetPath
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

extension File.System.Link.Read.Target.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notASymlink(let path):
            return "Not a symbolic link: \(path)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .readFailed(let errno, let message):
            return "Read link target failed: \(message) (errno=\(errno))"
        }
    }
}
