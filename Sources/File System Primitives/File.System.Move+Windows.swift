//
//  File.System.Move+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    import WinSDK

    extension File.System.Move {
        /// Moves a file using Windows APIs.
        internal static func _moveWindows(
            from source: File.Path,
            to destination: File.Path,
            options: Options
        ) throws(Error) {
            // Check if source exists
            let srcAttrs = source.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard srcAttrs != INVALID_FILE_ATTRIBUTES else {
                throw .sourceNotFound(source)
            }

            // Check destination
            let dstAttrs = destination.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            if dstAttrs != INVALID_FILE_ATTRIBUTES && !options.overwrite {
                throw .destinationExists(destination)
            }

            // Build flags
            var flags: DWORD = _dword(MOVEFILE_COPY_ALLOWED)  // Allow cross-volume moves
            if options.overwrite {
                flags |= _dword(MOVEFILE_REPLACE_EXISTING)
            }

            let success = source.string.withCString(encodedAs: UTF16.self) { wsrc in
                destination.string.withCString(encodedAs: UTF16.self) { wdst in
                    MoveFileExW(wsrc, wdst, flags)
                }
            }

            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), source: source, destination: destination)
            }
        }

        /// Maps Windows error to move error.
        private static func _mapWindowsError(
            _ error: DWORD,
            source: File.Path,
            destination: File.Path
        ) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .sourceNotFound(source)
            case _dword(ERROR_FILE_EXISTS), _dword(ERROR_ALREADY_EXISTS):
                return .destinationExists(destination)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(source)
            default:
                return .moveFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif
