//
//  File.System.Parent.Check+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

#if os(Windows)

    import WinSDK

    // MARK: - Verification

    extension File.System.Parent.Check {
        /// Verifies that a parent directory exists and is accessible.
        ///
        /// - Parameters:
        ///   - dir: The path to verify.
        ///   - createIntermediates: If `true`, attempts to create the directory if it doesn't exist.
        /// - Throws: `File.System.Parent.Check.Error` if verification fails.
        static func verify(
            _ dir: String,
            createIntermediates: Bool
        ) throws(File.System.Parent.Check.Error) {
            let attrs = dir.withCString(encodedAs: UTF16.self) { GetFileAttributesW($0) }

            if attrs == INVALID_FILE_ATTRIBUTES {
                let err = GetLastError()
                let path = File.Path(__unchecked: (), dir)

                switch err {
                case _dword(ERROR_ACCESS_DENIED), _dword(ERROR_SHARING_VIOLATION):
                    throw .accessDenied(path: path)
                case _dword(ERROR_DIRECTORY):
                    throw .notDirectory(path: path)
                case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                    // Only these are eligible for createIntermediates
                    if createIntermediates {
                        try createParent(at: path)
                        return
                    }
                    throw .missing(path: path)
                case _dword(ERROR_INVALID_NAME), _dword(ERROR_BAD_PATHNAME),
                    _dword(ERROR_INVALID_DRIVE):
                    throw .invalidPath(path: path)
                case _dword(ERROR_BAD_NETPATH), _dword(ERROR_BAD_NET_NAME):
                    throw .networkPathNotFound(path: path)
                default:
                    throw .statFailed(
                        path: path,
                        operation: .getFileAttributes,
                        code: .windows(err)
                    )
                }
            }

            if (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) == 0 {
                throw .notDirectory(path: File.Path(__unchecked: (), dir))
            }
        }

        private static func createParent(at path: File.Path) throws(File.System.Parent.Check.Error)
        {
            do {
                try File.System.Create.Directory.create(
                    at: path,
                    options: .init(createIntermediates: true)
                )
            } catch let createError {
                // Preserve the underlying error - it already contains the Windows error code
                throw .creationFailed(path: path, underlying: createError)
            }
        }
    }

#endif
