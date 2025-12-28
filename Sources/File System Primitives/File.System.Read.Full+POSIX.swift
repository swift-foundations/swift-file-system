//
//  File.System.Read.Full+POSIX.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    extension File.System.Read.Full {
        /// Reads file contents using POSIX APIs.
        internal static func _readPOSIX(
            from path: File.Path
        ) throws(File.System.Read.Full.Error) -> [UInt8] {
            // Open file for reading
            let fd = open(String(path), O_RDONLY)
            guard fd >= 0 else {
                throw _mapErrno(errno, path: path)
            }

            defer { _ = close(fd) }

            // Get file size via fstat
            var statBuf = stat()
            guard fstat(fd, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            // Check if it's a directory
            if (statBuf.st_mode & S_IFMT) == S_IFDIR {
                throw .isDirectory(path)
            }

            let fileSize = Int(statBuf.st_size)

            // Handle empty file
            if fileSize == 0 {
                return []
            }

            // Capture error state from non-throwing closure
            var readError: Error? = nil

            // Allocate uninitialized buffer and read directly into it
            let buffer = [UInt8](unsafeUninitializedCapacity: fileSize) {
                buffer,
                initializedCount in
                guard let base = buffer.baseAddress else {
                    initializedCount = 0
                    return
                }

                var totalRead = 0

                while totalRead < fileSize {
                    let remaining = fileSize - totalRead
                    #if canImport(Darwin)
                        let bytesRead = Darwin.read(fd, base.advanced(by: totalRead), remaining)
                    #elseif canImport(Glibc)
                        let bytesRead = Glibc.read(fd, base.advanced(by: totalRead), remaining)
                    #elseif canImport(Musl)
                        let bytesRead = Musl.read(fd, base.advanced(by: totalRead), remaining)
                    #endif

                    if bytesRead > 0 {
                        totalRead += bytesRead
                    } else if bytesRead == 0 {
                        // EOF reached earlier than expected (file may have shrunk)
                        break
                    } else {
                        // Error
                        let e = errno
                        if e == EINTR {
                            continue  // Interrupted, retry
                        }
                        readError = _mapErrno(e, path: path)
                        // Set initializedCount to totalRead for memory correctness
                        initializedCount = totalRead
                        return
                    }
                }

                initializedCount = totalRead
            }

            if let error = readError {
                throw error
            }
            return buffer
        }

        /// Maps errno to read error.
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EISDIR:
                return .isDirectory(path)
            case EMFILE, ENFILE:
                return .tooManyOpenFiles
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
