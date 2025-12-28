//
//  File.Directory.Walk+FTS.swift
//  swift-file-system
//
//  Internal FTS-based walker for fast single-threaded traversal on POSIX.
//

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension File.Directory.Walk {
    /// Internal FTS-based walker for fast single-threaded traversal.
    ///
    /// This uses the POSIX `fts(3)` API which provides efficient,
    /// single-pass directory tree traversal with built-in cycle detection.
    ///
    /// ## Usage
    /// ```swift
    /// var walker = try File.Directory.Walk.FTS(path: rootPath)
    /// defer { walker.close() }
    /// while let entry = try walker.next() {
    ///     process(entry)
    /// }
    /// ```
    package struct FTS {
        #if canImport(Darwin)
        private var ftsPointer: UnsafeMutablePointer<Darwin.FTS>?
        #elseif canImport(Glibc)
        private var ftsPointer: UnsafeMutablePointer<Glibc.FTS>?
        #elseif canImport(Musl)
        private var ftsPointer: UnsafeMutablePointer<Musl.FTS>?
        #endif
        private let rootPath: File.Path

        /// Opens an FTS traversal at the given path.
        ///
        /// - Parameter path: The root directory to traverse.
        /// - Throws: `Error.openFailed` if fts_open fails.
        package init(path: File.Path) throws(Error) {
            self.rootPath = path

            let pathString = String(path)

            // fts_open requires a null-terminated array of path pointers
            // We allocate the path string and create the array
            guard let pathCString = strdup(pathString) else {
                throw .openFailed(errno: ENOMEM, message: "Failed to allocate path string")
            }

            var paths: [UnsafeMutablePointer<CChar>?] = [pathCString, nil]

            // FTS_PHYSICAL: don't follow symlinks (lstat behavior)
            // FTS_NOCHDIR: don't chdir into directories (thread-safe)
            // FTS_NOSTAT: don't call stat for each entry (we may need to for filtering)
            let options: Int32 = FTS_PHYSICAL | FTS_NOCHDIR

            guard let fts = fts_open(&paths, options, nil) else {
                free(pathCString)
                throw .openFailed(errno: errno, message: String(cString: strerror(errno)))
            }

            // fts_open copies the paths, so we can free our copy
            free(pathCString)

            self.ftsPointer = fts
        }

        /// Returns the next entry in the traversal.
        ///
        /// - Returns: The next path, or nil if traversal is complete.
        /// - Throws: `Error.readFailed` if fts_read encounters an error.
        package mutating func next() throws(Error) -> Entry? {
            guard let fts = ftsPointer else {
                return nil
            }

            while true {
                guard let ftsent = fts_read(fts) else {
                    // Check if this is an error or end of traversal
                    if errno != 0 {
                        let e = errno
                        errno = 0
                        throw .readFailed(errno: e, message: String(cString: strerror(e)))
                    }
                    return nil // End of traversal
                }

                let info = Int32(ftsent.pointee.fts_info)

                switch info {
                case FTS_D:
                    // Directory in pre-order
                    // Skip root directory (depth 0) to match concurrent walker behavior
                    let depth = Int(ftsent.pointee.fts_level)
                    if depth == 0 { continue }
                    return Entry(
                        path: File.Path(cString: ftsent.pointee.fts_path),
                        type: .directory,
                        depth: depth
                    )

                case FTS_F:
                    // Regular file
                    return Entry(
                        path: File.Path(cString: ftsent.pointee.fts_path),
                        type: .file,
                        depth: Int(ftsent.pointee.fts_level)
                    )

                case FTS_SL, FTS_SLNONE:
                    // Symbolic link (SL = valid target, SLNONE = broken)
                    return Entry(
                        path: File.Path(cString: ftsent.pointee.fts_path),
                        type: .symbolicLink,
                        depth: Int(ftsent.pointee.fts_level)
                    )

                case FTS_DEFAULT:
                    // Other file types (socket, fifo, device, etc.)
                    return Entry(
                        path: File.Path(cString: ftsent.pointee.fts_path),
                        type: .other,
                        depth: Int(ftsent.pointee.fts_level)
                    )

                case FTS_DP:
                    // Directory in post-order - skip (already yielded in pre-order)
                    continue

                case FTS_DOT:
                    // . or .. - skip
                    continue

                case FTS_DC:
                    // Directory causing a cycle - skip
                    continue

                case FTS_DNR:
                    // Directory that couldn't be read - skip
                    continue

                case FTS_ERR:
                    // Error entry - skip (could optionally throw)
                    continue

                case FTS_NS:
                    // No stat info available - skip
                    continue

                default:
                    // Unknown type - skip
                    continue
                }
            }
        }

        /// Closes the FTS traversal and releases resources.
        package mutating func close() {
            if let fts = ftsPointer {
                fts_close(fts)
                ftsPointer = nil
            }
        }

        /// An entry returned by the FTS walker.
        package struct Entry: Sendable {
            /// The full path to this entry.
            package let path: File.Path

            /// The type of this entry.
            package let type: Kind

            /// The depth of this entry relative to the root (0 = root itself).
            package let depth: Int

            package enum Kind: Sendable {
                case file
                case directory
                case symbolicLink
                case other
            }
        }

        /// Errors that can occur during FTS traversal.
        package enum Error: Swift.Error, Sendable {
            case openFailed(errno: Int32, message: String)
            case readFailed(errno: Int32, message: String)
        }
    }
}

#endif
