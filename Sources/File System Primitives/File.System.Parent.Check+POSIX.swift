//
//  File.System.Parent.Check+POSIX.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    // MARK: - Verification

    extension File.System.Parent.Check {
        /// Verifies that a parent directory exists and is accessible.
        ///
        /// - Parameters:
        ///   - path: The path to verify.
        ///   - createIntermediates: If `true`, attempts to create the directory if it doesn't exist.
        /// - Throws: `File.System.Parent.Check.Error` if verification fails.
        static func verify(
            _ path: File.Path,
            createIntermediates: Bool
        ) throws(File.System.Parent.Check.Error) {
            var st = stat()
            let rc = path.withCString { stat($0, &st) }

            if rc != 0 {
                let e = errno

                switch e {
                case EACCES:
                    throw .accessDenied(path: path)
                case ENOTDIR:
                    throw .notDirectory(path: path)
                case ENOENT:
                    // Only ENOENT is eligible for createIntermediates
                    if createIntermediates {
                        try createParent(at: path)
                        return
                    }
                    throw .missing(path: path)
                case ELOOP:
                    // Symlink loop - terminal, cannot be fixed by creating directories
                    throw .statFailed(path: path, operation: .stat, code: .posix(ELOOP))
                default:
                    // EIO, ENAMETOOLONG, EINVAL, etc. - terminal
                    throw .statFailed(path: path, operation: .stat, code: .posix(e))
                }
            }

            if (st.st_mode & S_IFMT) != S_IFDIR {
                throw .notDirectory(path: path)
            }
        }

        private static func createParent(at path: File.Path) throws(File.System.Parent.Check.Error) {
            do {
                try File.System.Create.Directory.create(
                    at: path,
                    options: .init(createIntermediates: true)
                )
            } catch let createError {
                // Preserve the underlying error - it already contains the errno
                throw .creationFailed(path: path, underlying: createError)
            }
        }
    }

#endif
