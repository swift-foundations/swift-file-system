//
//  File.Descriptor+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    public import WinSDK

    extension File.Descriptor {
        /// Opens a file using Windows APIs.
        @usableFromInline
        internal static func _openWindows(
            _ path: File.Path,
            mode: Mode,
            options: Options
        ) throws(Error) -> File.Descriptor {
            var desiredAccess: DWORD = 0
            // Include FILE_SHARE_DELETE for POSIX-like rename/unlink semantics
            var shareMode: DWORD =
                _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE)
            var creationDisposition: DWORD = _dword(OPEN_EXISTING)
            var flagsAndAttributes: DWORD = _mask(FILE_ATTRIBUTE_NORMAL)

            // Set access mode
            switch mode {
            case .read:
                desiredAccess = _dword(GENERIC_READ)
            case .write:
                desiredAccess = _dword(GENERIC_WRITE)
            case .readWrite:
                desiredAccess = _dword(GENERIC_READ) | _dword(GENERIC_WRITE)
            }

            // Set creation disposition based on options
            if options.contains(.create) {
                if options.contains(.exclusive) {
                    creationDisposition = _dword(CREATE_NEW)
                } else if options.contains(.truncate) {
                    creationDisposition = _dword(CREATE_ALWAYS)
                } else {
                    creationDisposition = _dword(OPEN_ALWAYS)
                }
            } else if options.contains(.truncate) {
                creationDisposition = _dword(TRUNCATE_EXISTING)
            }

            // Append mode - combine with existing access, don't clobber
            if options.contains(.append) {
                desiredAccess |= _mask(FILE_APPEND_DATA)
            }

            // No follow symlinks
            if options.contains(.noFollow) {
                flagsAndAttributes |= _mask(FILE_FLAG_OPEN_REPARSE_POINT)
            }

            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    desiredAccess,
                    shareMode,
                    nil,
                    creationDisposition,
                    flagsAndAttributes,
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            // Close on exec - prevent handle inheritance
            if options.contains(.closeOnExec) {
                guard _ok(SetHandleInformation(handle, _dword(HANDLE_FLAG_INHERIT), 0)) else {
                    let error = GetLastError()
                    CloseHandle(handle)
                    throw .openFailed(
                        errno: Int32(error),
                        message: "SetHandleInformation failed: \(_formatWindowsError(error))"
                    )
                }
            }

            return File.Descriptor(__unchecked: handle)
        }

        /// Maps Windows error code to a descriptor error.
        @usableFromInline
        internal static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_FILE_EXISTS), _dword(ERROR_ALREADY_EXISTS):
                return .alreadyExists(path)
            case _dword(ERROR_TOO_MANY_OPEN_FILES):
                return .tooManyOpenFiles
            default:
                return .openFailed(errno: Int32(error), message: _formatWindowsError(error))
            }
        }

        /// Formats a Windows error code into a human-readable message.
        @usableFromInline
        internal static func _formatWindowsError(_ errorCode: DWORD) -> String {
            var buffer: LPWSTR? = nil

            // FormatMessageW with FORMAT_MESSAGE_ALLOCATE_BUFFER expects a pointer to LPWSTR
            // but is typed as pointer to WCHAR. Use withUnsafeMutablePointer to work around.
            let length = withUnsafeMutablePointer(to: &buffer) { bufferPtr in
                bufferPtr.withMemoryRebound(to: WCHAR.self, capacity: 1) { wcharPtr in
                    FormatMessageW(
                        _mask(FORMAT_MESSAGE_ALLOCATE_BUFFER) | _mask(FORMAT_MESSAGE_FROM_SYSTEM)
                            | _mask(FORMAT_MESSAGE_IGNORE_INSERTS),
                        nil,
                        errorCode,
                        0,
                        wcharPtr,
                        0,
                        nil
                    )
                }
            }

            guard length > 0, let buffer = buffer else {
                return "Windows error \(errorCode)"
            }
            defer { LocalFree(buffer) }

            // Manual trimming without Foundation
            var str = String(decodingCString: buffer, as: UTF16.self)
            while let last = str.last, last.isWhitespace || last.isNewline {
                str.removeLast()
            }
            return str
        }
    }

#endif
