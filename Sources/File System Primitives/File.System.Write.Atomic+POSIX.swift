// File.System.Write.Atomic+POSIX.swift
// POSIX implementation of atomic file writes (macOS, Linux, BSD)

#if !os(Windows)

    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import CFileSystemShims
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif

    import RFC_4648

    // MARK: - Syscall Injection (DEBUG only)

    #if DEBUG
        /// Injectable syscall layer for testing error paths.
        /// All syscall wrappers check these overrides first.
        enum SyscallOverrides {
            nonisolated(unsafe) static var openOverride: (
                (UnsafePointer<CChar>, Int32, mode_t) -> Int32
            )?
            nonisolated(unsafe) static var fsyncOverride: ((Int32) -> Int32)?
            nonisolated(unsafe) static var fdatasyncOverride: ((Int32) -> Int32)?
            nonisolated(unsafe) static var getrandomOverride: (
                (UnsafeMutableRawPointer, Int, UInt32) -> Int
            )?
            nonisolated(unsafe) static var renameOverride: (
                (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
            )?
            nonisolated(unsafe) static var renameat2Override: (
                (String, String) -> (result: Int32, errno: Int32)
            )?

            /// Reset all overrides (call in test tearDown)
            static func reset() {
                openOverride = nil
                fsyncOverride = nil
                fdatasyncOverride = nil
                getrandomOverride = nil
                renameOverride = nil
                renameat2Override = nil
            }
        }
    #endif

    // MARK: - EINTR-Safe Syscall Wrappers

    /// Retry open() on EINTR. Returns fd ≥ 0 on success, -1 on error.
    /// EINTR is safe to retry for open() as it has no side effects on interrupt.
    @inline(__always)
    private func openRetryingEINTR(
        _ path: UnsafePointer<CChar>,
        _ flags: Int32,
        _ mode: mode_t
    ) -> Int32 {
        while true {
            #if DEBUG
                let fd =
                    SyscallOverrides.openOverride?(path, flags, mode) ?? open(path, flags, mode)
            #else
                let fd = open(path, flags, mode)
            #endif
            if fd >= 0 || errno != EINTR { return fd }
        }
    }

    /// Retry open() without mode (for O_RDONLY). Returns fd ≥ 0 on success, -1 on error.
    @inline(__always)
    private func openRetryingEINTR(
        _ path: UnsafePointer<CChar>,
        _ flags: Int32
    ) -> Int32 {
        while true {
            #if DEBUG
                let fd = SyscallOverrides.openOverride?(path, flags, 0) ?? open(path, flags)
            #else
                let fd = open(path, flags)
            #endif
            if fd >= 0 || errno != EINTR { return fd }
        }
    }

    /// Retry fsync() on EINTR. Returns 0 on success, -1 on error.
    /// fsync() is idempotent and safe to retry.
    @inline(__always)
    private func fsyncRetryingEINTR(_ fd: Int32) -> Int32 {
        while true {
            #if DEBUG
                let rc = SyscallOverrides.fsyncOverride?(fd) ?? fsync(fd)
            #else
                let rc = fsync(fd)
            #endif
            if rc == 0 || errno != EINTR { return rc }
        }
    }

    #if os(Linux)
        /// Retry fdatasync() on EINTR. Returns 0 on success, -1 on error.
        /// fdatasync() is idempotent and safe to retry.
        @inline(__always)
        private func fdatasyncRetryingEINTR(_ fd: Int32) -> Int32 {
            while true {
                #if DEBUG
                    let rc = SyscallOverrides.fdatasyncOverride?(fd) ?? fdatasync(fd)
                #else
                    let rc = fdatasync(fd)
                #endif
                if rc == 0 || errno != EINTR { return rc }
            }
        }
    #endif

    // MARK: - Portability Shims

    #if os(Linux)
        /// Linux uses ENOTSUP; other platforms use EOPNOTSUPP.
        /// They may be the same value, but this ensures correctness.
        private let ENOTSUPP_OR_NOTSUP = ENOTSUP
    #else
        private let ENOTSUPP_OR_NOTSUP = EOPNOTSUPP
    #endif

    // MARK: - POSIX Implementation

    enum POSIXAtomic {

        static func writeSpan(
            _ bytes: borrowing Swift.Span<UInt8>,
            to path: borrowing String,
            options: borrowing File.System.Write.Atomic.Options
        ) throws(File.System.Write.Atomic.Error) {
            typealias Phase = File.System.Write.Atomic.Commit.Phase

            // Track progress for cleanup and error diagnostics
            var phase: Phase = .pending

            // 1. Resolve and validate parent directory
            let resolvedPath = resolvePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyParentDirectory(parent)

            // 2. Stat destination if it exists (for metadata preservation)
            let destStat = try statIfExists(resolvedPath)

            // 3. Create temp file with unique name (retries on EEXIST)
            let (fd, tempPath) = try createTempFileWithRetry(in: parent, for: resolvedPath)
            phase = .writing

            defer {
                // CRITICAL: After renamedPublished, NEVER unlink destination!
                // Only cleanup temp file if rename hasn't happened yet.
                if phase < .closed {
                    _ = close(fd)
                }
                if phase < .renamedPublished {
                    _ = unlink(tempPath)
                }
                // Note: if phase >= .renamedPublished, temp no longer exists (was renamed)
            }

            // 4. Write all data
            try writeAll(bytes, to: fd)

            // 5. Sync file to disk
            try syncFile(fd, durability: options.durability)
            phase = .syncedFile

            // 6. Apply metadata from destination if requested
            if let st = destStat {
                try applyMetadata(from: st, to: fd, options: options, destPath: resolvedPath)
            }

            // 7. Close file (required before rename on some systems)
            try closeFile(fd)
            phase = .closed

            // 8. Atomic rename
            switch options.strategy {
            case .replaceExisting:
                try atomicRename(from: tempPath, to: resolvedPath)
            case .noClobber:
                try atomicRenameNoClobber(from: tempPath, to: resolvedPath)
            }
            // CRITICAL: Update phase IMMEDIATELY after successful rename
            phase = .renamedPublished

            // 9. Sync directory to persist the rename - only for .full durability.
            // Directory sync is a metadata persistence step, so it should NOT be
            // performed for .dataOnly (which explicitly states "metadata may not
            // be persisted"). If this fails after publish, the file IS published
            // but durability is not guaranteed.
            if options.durability == .full {
                phase = .directorySyncAttempted  // Mark attempt BEFORE syscall
                do {
                    try syncDirectory(parent)
                    phase = .syncedDirectory
                } catch let syncError {
                    // Already published, report as after-commit failure
                    if case .directorySyncFailed(let path, let code, let msg) = syncError {
                        throw .directorySyncFailedAfterCommit(
                            path: path,
                            code: code,
                            message: msg
                        )
                    }
                    throw syncError
                }
            } else {
                // No directory sync requested, consider it "complete"
                phase = .syncedDirectory
            }
        }
    }

    // MARK: - Path Handling

    extension POSIXAtomic {

        /// Resolves a path, expanding ~ and making relative paths absolute.
        private static func resolvePath(_ path: String) -> String {
            var result = path

            // Expand ~ to home directory
            if result.hasPrefix("~/") {
                if let home = getenv("HOME") {
                    result = String(cString: home) + String(result.dropFirst())
                }
            } else if result == "~" {
                if let home = getenv("HOME") {
                    result = String(cString: home)
                }
            }

            // Make relative paths absolute using current working directory
            if !result.hasPrefix("/") {
                // Use stack allocation for getcwd buffer
                withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PATH_MAX)) { buffer in
                    if getcwd(buffer.baseAddress!, buffer.count) != nil {
                        // cwd is already null-terminated by getcwd - use String(cString:) directly
                        let cwdStr = String(cString: buffer.baseAddress!)
                        if result == "." {
                            result = cwdStr
                        } else if result.hasPrefix("./") {
                            result = cwdStr + String(result.dropFirst())
                        } else {
                            result = cwdStr + "/" + result
                        }
                    }
                }
            }

            // Normalize: remove trailing slashes (except root)
            while result.count > 1 && result.hasSuffix("/") {
                result.removeLast()
            }

            return result
        }

        /// Extracts the parent directory from a path.
        private static func parentDirectory(of path: String) -> String {
            // Root has no parent
            if path == "/" { return "/" }

            // Find last slash
            guard let lastSlash = path.lastIndex(of: "/") else {
                // No slash means current directory (shouldn't happen after resolvePath)
                return "."
            }

            if lastSlash == path.startIndex {
                // Path like "/file" - parent is root
                return "/"
            }

            return String(path[..<lastSlash])
        }

        /// Extracts the filename from a path.
        private static func fileName(of path: String) -> String {
            if let lastSlash = path.lastIndex(of: "/") {
                return String(path[path.index(after: lastSlash)...])
            }
            return path
        }

        /// Verifies the parent directory exists and is accessible.
        private static func verifyParentDirectory(
            _ dir: String
        ) throws(File.System.Write.Atomic.Error) {
            var st = stat()
            let rc = dir.withCString { stat($0, &st) }

            if rc != 0 {
                let e = errno
                let path = File.Path(__unchecked: (), dir)
                switch e {
                case EACCES:
                    throw .parentAccessDenied(path: path)
                case ENOTDIR:
                    // A component of the path prefix is not a directory
                    throw .parentNotDirectory(path: path)
                case ENOENT, ELOOP:
                    // ENOENT: path doesn't exist
                    // ELOOP: too many symlinks (treat as not found)
                    throw .parentNotFound(path: path)
                default:
                    throw .parentNotFound(path: path)
                }
            }

            if (st.st_mode & S_IFMT) != S_IFDIR {
                throw .parentNotDirectory(path: File.Path(__unchecked: (), dir))
            }
        }

        /// Maximum attempts for temp file creation.
        /// 64 attempts is cheap (just random token generation) and prevents flaky failures
        /// under high concurrency.
        private static let maxTempFileAttempts = 64

        /// Creates a temp file with a unique name, retrying on EEXIST.
        ///
        /// Combines path generation and file creation into a single operation with retry logic.
        /// Uses format: `.{basename}.atomic.{pid}.{random}.tmp` for uniqueness across processes.
        ///
        /// - Returns: A tuple of (file descriptor, temp file path).
        /// - Throws: `.tempFileCreationFailed` after max attempts or on non-EEXIST errors.
        private static func createTempFileWithRetry(
            in parent: String,
            for destPath: String
        ) throws(File.System.Write.Atomic.Error) -> (fd: Int32, tempPath: String) {
            let baseName = fileName(of: destPath)
            let pid = getpid()  // Stable prefix for cross-process uniqueness
            let flags: Int32 = O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC
            let mode: mode_t = 0o600  // Owner read/write only initially

            for attempt in 0..<maxTempFileAttempts {
                let random = try randomToken(length: 12)
                // Format: .{basename}.atomic.{pid}.{random}.tmp
                let tempPath = "\(parent)/.\(baseName).atomic.\(pid).\(random).tmp"

                let fd = tempPath.withCString { openRetryingEINTR($0, flags, mode) }

                if fd >= 0 {
                    return (fd, tempPath)
                }

                let e = errno
                // Retry on EEXIST (name collision) unless this is the last attempt
                if e == EEXIST && attempt < maxTempFileAttempts - 1 {
                    continue
                }

                throw .tempFileCreationFailed(
                    directory: File.Path(__unchecked: (), parent),
                    code: .posix(e),
                    message: e == EEXIST
                        ? "Failed after \(maxTempFileAttempts) attempts (EEXIST)"
                        : File.System.Write.Atomic.errorMessage(for: e)
                )
            }

            // Should not be reached due to loop structure, but Swift requires exhaustive return
            throw .tempFileCreationFailed(
                directory: File.Path(__unchecked: (), parent),
                code: .posix(EEXIST),
                message: "Failed after \(maxTempFileAttempts) attempts"
            )
        }

        /// Generates a random hex token using platform CSPRNG.
        /// Uses stack allocation and arc4random_buf/getrandom for better performance
        /// and cryptographic security compared to UInt8.random loop.
        ///
        /// - Throws: `.randomGenerationFailed` if CSPRNG syscall fails (extremely rare).
        private static func randomToken(
            length: Int
        ) throws(File.System.Write.Atomic.Error) -> String {
            // Token length is fixed at 12 bytes
            precondition(length == 12, "randomToken expects fixed length of 12")

            // Use error capture pattern to work around typed throws in closures
            var getrandomError: File.System.Write.Atomic.Error? = nil

            let result = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer in
                let base = buffer.baseAddress!

                #if canImport(Darwin)
                    // arc4random_buf never fails
                    arc4random_buf(base, length)

                #elseif canImport(Glibc) || canImport(Musl)
                    // Use C shim wrapper for getrandom syscall
                    var filled = 0
                    while filled < length {
                        #if DEBUG
                        let result = SyscallOverrides.getrandomOverride?(
                            base.advanced(by: filled),
                            length - filled,
                            0
                        ) ?? Int(atomicfilewrite_getrandom(
                            base.advanced(by: filled),
                            length - filled,
                            0
                        ))
                        #else
                        let result = Int(atomicfilewrite_getrandom(
                            base.advanced(by: filled),
                            length - filled,
                            0
                        ))
                        #endif
                        if result > 0 {
                            filled += result
                        } else if result == -1 {
                            let e = errno
                            if e == EINTR { continue }  // Retry on interrupt
                            // CSPRNG failure - cannot proceed safely
                            getrandomError = .randomGenerationFailed(
                                code: .posix(e),
                                operation: "getrandom",
                                message: "CSPRNG syscall failed"
                            )
                            return ""  // Return empty, will throw after
                        }
                    }
                #endif

                // Encode to hex (Foundation-free via RFC_4648)
                return Span(_unsafeElements: buffer).hex.encoded()
            }

            if let error = getrandomError {
                throw error
            }
            return result
        }
    }

    // MARK: - File Operations

    extension POSIXAtomic {

        /// Stats a file, returning nil if it doesn't exist.
        private static func statIfExists(
            _ path: String
        ) throws(File.System.Write.Atomic.Error) -> stat? {
            var st = stat()
            let rc = path.withCString { lstat($0, &st) }

            if rc == 0 {
                return st
            }

            let e = errno
            if e == ENOENT {
                return nil
            }

            throw .destinationStatFailed(
                path: File.Path(__unchecked: (), path),
                code: .posix(e),
                message: File.System.Write.Atomic.errorMessage(for: e)
            )
        }

        /// Writes all bytes to the file descriptor, handling partial writes and interrupts.
        private static func writeAll(
            _ bytes: borrowing Swift.Span<UInt8>,
            to fd: Int32
        ) throws(File.System.Write.Atomic.Error) {
            let total = bytes.count
            if total == 0 { return }

            var written = 0

            try bytes.withUnsafeBufferPointer { buffer throws(File.System.Write.Atomic.Error) in
                guard let base = buffer.baseAddress else {
                    throw .writeFailed(
                        bytesWritten: 0,
                        bytesExpected: total,
                        code: .posix(0),
                        message: "nil buffer"
                    )
                }

                while written < total {
                    let remaining = total - written
                    let rc = write(fd, base.advanced(by: written), remaining)

                    if rc > 0 {
                        written += rc
                        continue
                    }

                    if rc == 0 {
                        // Shouldn't happen with regular files, but handle it
                        throw .writeFailed(
                            bytesWritten: written,
                            bytesExpected: total,
                            code: .posix(0),
                            message: "write returned 0"
                        )
                    }

                    let e = errno
                    // Retry on interrupt or would-block
                    if e == EINTR || e == EAGAIN {
                        continue
                    }

                    throw .writeFailed(
                        bytesWritten: written,
                        bytesExpected: total,
                        code: .posix(e),
                        message: File.System.Write.Atomic.errorMessage(for: e)
                    )
                }
            }
        }

        /// Syncs file data to disk based on durability mode.
        /// Uses EINTR-safe wrappers for fsync/fdatasync.
        private static func syncFile(
            _ fd: Int32,
            durability: File.System.Write.Atomic.Durability
        ) throws(File.System.Write.Atomic.Error) {
            switch durability {
            case .full:
                // Full durability: F_FULLFSYNC on macOS, fsync elsewhere
                #if canImport(Darwin)
                    // On macOS, use F_FULLFSYNC for true durability
                    // Note: fcntl with F_FULLFSYNC can also return EINTR, but fcntl
                    // is not safe to blindly retry. We fall back to fsync on failure.
                    if fcntl(fd, F_FULLFSYNC) != 0 {
                        // Fall back to fsync if F_FULLFSYNC fails
                        if fsyncRetryingEINTR(fd) != 0 {
                            let e = errno
                            throw .syncFailed(
                                code: .posix(e),
                                message: File.System.Write.Atomic.errorMessage(for: e)
                            )
                        }
                    }
                #else
                    if fsyncRetryingEINTR(fd) != 0 {
                        let e = errno
                        throw .syncFailed(
                            code: .posix(e),
                            message: File.System.Write.Atomic.errorMessage(for: e)
                        )
                    }
                #endif

            case .dataOnly:
                // Data-only sync: fdatasync on Linux, F_BARRIERFSYNC on macOS, fallback to fsync
                #if canImport(Darwin)
                    // Try F_BARRIERFSYNC first (faster than F_FULLFSYNC)
                    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                        if fcntl(fd, F_BARRIERFSYNC) != 0 {
                            // Fall back to fsync if F_BARRIERFSYNC fails
                            if fsyncRetryingEINTR(fd) != 0 {
                                let e = errno
                                throw .syncFailed(
                                    code: .posix(e),
                                    message: File.System.Write.Atomic.errorMessage(for: e)
                                )
                            }
                        }
                    #else
                        // Darwin platform without F_BARRIERFSYNC, use fsync
                        if fsyncRetryingEINTR(fd) != 0 {
                            let e = errno
                            throw .syncFailed(
                                code: .posix(e),
                                message: File.System.Write.Atomic.errorMessage(for: e)
                            )
                        }
                    #endif
                #elseif os(Linux)
                    // Use fdatasync on Linux (syncs data but not all metadata)
                    if fdatasyncRetryingEINTR(fd) != 0 {
                        let e = errno
                        throw .syncFailed(
                            code: .posix(e),
                            message: File.System.Write.Atomic.errorMessage(for: e)
                        )
                    }
                #else
                    // Fallback to fsync for other platforms
                    if fsyncRetryingEINTR(fd) != 0 {
                        let e = errno
                        throw .syncFailed(
                            code: .posix(e),
                            message: File.System.Write.Atomic.errorMessage(for: e)
                        )
                    }
                #endif

            case .none:
                // No sync - fastest but no crash-safety guarantees
                // Data may remain in OS buffers and be lost on power failure
                break
            }
        }

        /// Closes a file descriptor exactly once.
        ///
        /// POSIX: fd state is undefined after EINTR on close(). The fd may or may not
        /// have been closed. Retrying risks closing an unrelated fd that was assigned
        /// the same number by another thread. Therefore we do NOT retry on EINTR.
        ///
        /// Reference: POSIX.1-2017, Linux close(2), and Austin Group interpretations.
        private static func closeFile(_ fd: Int32) throws(File.System.Write.Atomic.Error) {
            let rc = close(fd)
            if rc == 0 { return }
            let e = errno
            // Do NOT retry on EINTR - fd state is undefined, retrying is unsafe
            throw .closeFailed(code: .posix(e), message: File.System.Write.Atomic.errorMessage(for: e))
        }
    }

    // MARK: - Atomic Rename

    extension POSIXAtomic {

        /// Performs an atomic rename (replace if exists).
        private static func atomicRename(
            from: String,
            to: String
        ) throws(File.System.Write.Atomic.Error) {
            let rc = from.withCString { fromPtr in
                to.withCString { toPtr in
                    rename(fromPtr, toPtr)
                }
            }

            if rc != 0 {
                let e = errno
                throw .renameFailed(
                    from: File.Path(__unchecked: (), from),
                    to: File.Path(__unchecked: (), to),
                    code: .posix(e),
                    message: File.System.Write.Atomic.errorMessage(for: e)
                )
            }
        }

        /// Performs an atomic rename that fails if destination exists.
        ///
        /// On Linux, tries renameat2(RENAME_NOREPLACE) first for true atomicity.
        /// Falls back to check-then-rename if renameat2 is unavailable or unsupported.
        private static func atomicRenameNoClobber(
            from: String,
            to: String
        ) throws(File.System.Write.Atomic.Error) {
            #if os(Linux)
                // Try renameat2 with RENAME_NOREPLACE for true atomicity
                var renameat2Errno: Int32 = 0
                if let result = tryRenameat2NoClobber(from: from, to: to, errno: &renameat2Errno) {
                    if case .failure(let error) = result {
                        throw error
                    }
                    return  // Success
                }

                // renameat2 returned "try fallback" - attempt TOCTOU fallback
                // If EPERM was the original error and fallback also fails,
                // report the original EPERM to preserve diagnostic context.
                do {
                    try toctouRenameNoClobber(from: from, to: to)
                } catch let fallbackError {
                    // If original was EPERM and fallback also failed, report original
                    if renameat2Errno == EPERM {
                        throw .renameFailed(
                            from: File.Path(__unchecked: (), from),
                            to: File.Path(__unchecked: (), to),
                            code: .posix(EPERM),
                            message: "RENAME_NOREPLACE rejected (EPERM), fallback also failed"
                        )
                    }
                    throw fallbackError
                }
            #else
                // Non-Linux: use TOCTOU fallback directly
                try toctouRenameNoClobber(from: from, to: to)
            #endif
        }

        /// TOCTOU fallback for noClobber rename: check-then-rename.
        /// Has a race window, but matches behavior of most file APIs.
        private static func toctouRenameNoClobber(
            from: String,
            to: String
        ) throws(File.System.Write.Atomic.Error) {
            var st = stat()
            let exists = to.withCString { lstat($0, &st) } == 0

            if exists {
                throw .destinationExists(path: File.Path(__unchecked: (), to))
            }

            try atomicRename(from: from, to: to)
        }

        #if os(Linux)
            /// Tries to use renameat2(RENAME_NOREPLACE) on Linux.
            ///
            /// Returns:
            /// - `.success(())` if rename succeeded
            /// - `.failure(error)` for definitive errors (EEXIST = destination exists)
            /// - `nil` if renameat2 is unavailable or unsupported (caller should try fallback)
            ///
            /// The `errno` out parameter is set to the error code for diagnostics,
            /// especially when returning nil (to distinguish ENOSYS from EPERM).
            private static func tryRenameat2NoClobber(
                from: String,
                to: String,
                errno outErrno: inout Int32
            ) -> Result<Void, File.System.Write.Atomic.Error>? {
                #if DEBUG
                    // Support syscall injection for testing
                    if let override = SyscallOverrides.renameat2Override {
                        let result = override(from, to)
                        outErrno = result.errno
                        if result.result == 0 {
                            return .success(())
                        }
                        // Fall through to error handling below
                    } else {
                        let rc = from.withCString { fromPtr in
                            to.withCString { toPtr in
                                atomicfilewrite_renameat2_noreplace(fromPtr, toPtr, &outErrno)
                            }
                        }
                        if rc == 0 {
                            return .success(())
                        }
                    }
                #else
                    let rc = from.withCString { fromPtr in
                        to.withCString { toPtr in
                            atomicfilewrite_renameat2_noreplace(fromPtr, toPtr, &outErrno)
                        }
                    }

                    if rc == 0 {
                        return .success(())
                    }
                #endif

                switch outErrno {
                case EEXIST:
                    // Definitive: destination exists
                    return .failure(.destinationExists(path: File.Path(__unchecked: (), to)))

                case ENOSYS, EINVAL, ENOTSUPP_OR_NOTSUP:
                    // Feature unavailable - fall back to portable strategy
                    // ENOSYS: renameat2 syscall not available (old kernel < 3.15)
                    // EINVAL: flags not supported by filesystem
                    // ENOTSUP/EOPNOTSUPP: operation not supported
                    return nil

                case EPERM:
                    // EPERM is ambiguous: could be "flag rejected" OR real permission error.
                    // Return nil to try fallback, but preserve errno for diagnostics.
                    // If fallback also fails, caller will report original EPERM.
                    return nil

                default:
                    // Other errors are definitive failures
                    return .failure(
                        .renameFailed(
                            from: File.Path(__unchecked: (), from),
                            to: File.Path(__unchecked: (), to),
                            code: .posix(outErrno),
                            message: File.System.Write.Atomic.errorMessage(for: outErrno)
                        )
                    )
                }
            }
        #endif

        /// Syncs a directory to persist rename operations.
        /// Uses EINTR-safe wrappers for open() and fsync().
        private static func syncDirectory(_ path: String) throws(File.System.Write.Atomic.Error) {
            var flags: Int32 = O_RDONLY | O_CLOEXEC
            #if os(Linux)
                flags |= O_DIRECTORY
            #endif

            let fd = path.withCString { openRetryingEINTR($0, flags) }

            if fd < 0 {
                let e = errno
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    code: .posix(e),
                    message: File.System.Write.Atomic.errorMessage(for: e)
                )
            }

            defer { _ = close(fd) }

            if fsyncRetryingEINTR(fd) != 0 {
                let e = errno
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    code: .posix(e),
                    message: File.System.Write.Atomic.errorMessage(for: e)
                )
            }
        }
    }

    // MARK: - Metadata Preservation

    extension POSIXAtomic {

        /// Applies metadata from the original file to the temp file.
        private static func applyMetadata(
            from st: stat,
            to fd: Int32,
            options: File.System.Write.Atomic.Options,
            destPath: String
        ) throws(File.System.Write.Atomic.Error) {

            // Permissions (mode)
            if options.preservePermissions {
                let mode = st.st_mode & 0o7777
                if fchmod(fd, mode) != 0 {
                    let e = errno
                    throw .metadataPreservationFailed(
                        operation: "fchmod",
                        code: .posix(e),
                        message: File.System.Write.Atomic.errorMessage(for: e)
                    )
                }
            }

            // Ownership (uid/gid)
            if options.preserveOwnership {
                if fchown(fd, st.st_uid, st.st_gid) != 0 {
                    let e = errno
                    // Ownership changes often fail for non-root users
                    if options.strictOwnership {
                        throw .metadataPreservationFailed(
                            operation: "fchown",
                            code: .posix(e),
                            message: File.System.Write.Atomic.errorMessage(for: e)
                        )
                    }
                    // Otherwise silently ignore - this is expected for normal users
                }
            }

            // Timestamps
            if options.preserveTimestamps {
                try copyTimestamps(from: st, to: fd)
            }

            // Extended attributes
            if options.preserveExtendedAttributes {
                try copyExtendedAttributes(from: destPath, to: fd)
            }

            // ACLs
            if options.preserveACLs {
                try copyACL(from: destPath, to: fd)
            }
        }

        /// Copies atime/mtime from stat to file descriptor.
        private static func copyTimestamps(
            from st: stat,
            to fd: Int32
        ) throws(File.System.Write.Atomic.Error) {
            #if canImport(Darwin)
                var times = [
                    timespec(tv_sec: st.st_atimespec.tv_sec, tv_nsec: st.st_atimespec.tv_nsec),
                    timespec(tv_sec: st.st_mtimespec.tv_sec, tv_nsec: st.st_mtimespec.tv_nsec),
                ]
            #else
                var times = [
                    timespec(tv_sec: st.st_atim.tv_sec, tv_nsec: st.st_atim.tv_nsec),
                    timespec(tv_sec: st.st_mtim.tv_sec, tv_nsec: st.st_mtim.tv_nsec),
                ]
            #endif

            let rc = times.withUnsafeBufferPointer { futimens(fd, $0.baseAddress) }

            if rc != 0 {
                let e = errno
                throw .metadataPreservationFailed(
                    operation: "futimens",
                    code: .posix(e),
                    message: File.System.Write.Atomic.errorMessage(for: e)
                )
            }
        }
    }

    // MARK: - Extended Attributes

    extension POSIXAtomic {

        /// Copies extended attributes from source path to destination fd.
        private static func copyExtendedAttributes(
            from srcPath: String,
            to dstFd: Int32
        ) throws(File.System.Write.Atomic.Error) {
            #if canImport(Darwin)
                try copyXattrsDarwin(from: srcPath, to: dstFd)
            #else
                // Linux xattr requires C shim (planned for future release)
                // Other platforms - silently skip
                _ = (srcPath, dstFd)
            #endif
        }

        #if canImport(Darwin)
            private static func copyXattrsDarwin(
                from srcPath: String,
                to dstFd: Int32
            ) throws(File.System.Write.Atomic.Error) {
                // Get list of xattr names
                let listSize = srcPath.withCString { listxattr($0, nil, 0, 0) }

                if listSize < 0 {
                    let e = errno
                    if e == ENOTSUP || e == ENOENT { return }  // No xattr support or file gone
                    throw .metadataPreservationFailed(
                        operation: "listxattr",
                        code: .posix(e),
                        message: File.System.Write.Atomic.errorMessage(for: e)
                    )
                }

                if listSize == 0 { return }  // No xattrs

                // Stack threshold for xattr buffers
                let stackThreshold = 4096

                // Helper to process xattr list with a given buffer
                func processXattrList(
                    nameListBuffer: UnsafeMutableBufferPointer<CChar>
                ) throws(File.System.Write.Atomic.Error) {
                    // Read the name list
                    let gotSize = srcPath.withCString { path in
                        listxattr(path, nameListBuffer.baseAddress, listSize, 0)
                    }

                    if gotSize < 0 {
                        let e = errno
                        throw .metadataPreservationFailed(
                            operation: "listxattr(read)",
                            code: .posix(e),
                            message: File.System.Write.Atomic.errorMessage(for: e)
                        )
                    }

                    // Parse null-terminated names and copy each xattr
                    var offset = 0
                    while offset < gotSize {
                        // Find end of this name
                        var end = offset
                        while end < gotSize && nameListBuffer[end] != 0 { end += 1 }

                        // Decode xattr name without intermediate .map allocation
                        let start = nameListBuffer.baseAddress!.advanced(by: offset)
                        let count = end - offset
                        // Rebind CChar pointer to UInt8 for UTF-8 decoding
                        let name = start.withMemoryRebound(to: UInt8.self, capacity: count) {
                            utf8Start in
                            let utf8Buf = UnsafeBufferPointer(start: utf8Start, count: count)
                            return String(decoding: utf8Buf, as: UTF8.self)
                        }
                        offset = end + 1

                        // Get xattr value
                        let valueSize = srcPath.withCString { path in
                            name.withCString { n in
                                getxattr(path, n, nil, 0, 0, 0)
                            }
                        }

                        if valueSize < 0 {
                            let e = errno
                            if e == ENOATTR { continue }  // Attribute disappeared
                            throw .metadataPreservationFailed(
                                operation: "getxattr(\(name))",
                                code: .posix(e),
                                message: File.System.Write.Atomic.errorMessage(for: e)
                            )
                        }

                        // Helper to read and set xattr with a given buffer
                        func copyXattrValue(
                            buffer: UnsafeMutableBufferPointer<UInt8>
                        ) throws(File.System.Write.Atomic.Error) -> Int {
                            let gotValue = srcPath.withCString { path in
                                name.withCString { n in
                                    getxattr(path, n, buffer.baseAddress, valueSize, 0, 0)
                                }
                            }

                            if gotValue < 0 {
                                let e = errno
                                throw .metadataPreservationFailed(
                                    operation: "getxattr(\(name),read)",
                                    code: .posix(e),
                                    message: File.System.Write.Atomic.errorMessage(for: e)
                                )
                            }

                            // Set xattr on destination
                            let setRc = name.withCString { n in
                                fsetxattr(dstFd, n, buffer.baseAddress, gotValue, 0, 0)
                            }

                            if setRc < 0 {
                                let e = errno
                                if e == ENOTSUP {
                                    // Destination doesn't support this xattr, skip
                                    return gotValue
                                }
                                throw .metadataPreservationFailed(
                                    operation: "fsetxattr(\(name))",
                                    code: .posix(e),
                                    message: File.System.Write.Atomic.errorMessage(for: e)
                                )
                            }

                            return gotValue
                        }

                        // Use error capture pattern to work around typed throws in closures
                        var xattrError: File.System.Write.Atomic.Error? = nil

                        if valueSize <= stackThreshold {
                            // Stack allocation for small xattrs
                            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: valueSize) {
                                buffer in
                                do throws(File.System.Write.Atomic.Error) {
                                    _ = try copyXattrValue(buffer: buffer)
                                } catch {
                                    xattrError = error
                                }
                            }
                        } else {
                            // Heap allocation for large xattrs
                            var value = [UInt8](repeating: 0, count: valueSize)
                            value.withUnsafeMutableBufferPointer { buffer in
                                do throws(File.System.Write.Atomic.Error) {
                                    _ = try copyXattrValue(buffer: buffer)
                                } catch {
                                    xattrError = error
                                }
                            }
                        }

                        if let error = xattrError {
                            throw error
                        }
                    }
                }

                var listError: File.System.Write.Atomic.Error? = nil

                // Use stack allocation for small name lists, heap for large ones
                if listSize <= stackThreshold {
                    withUnsafeTemporaryAllocation(of: CChar.self, capacity: listSize) { buffer in
                        do throws(File.System.Write.Atomic.Error) {
                            try processXattrList(nameListBuffer: buffer)
                        } catch {
                            listError = error
                        }
                    }
                } else {
                    var nameList = [CChar](repeating: 0, count: listSize)
                    nameList.withUnsafeMutableBufferPointer { buffer in
                        do throws(File.System.Write.Atomic.Error) {
                            try processXattrList(nameListBuffer: buffer)
                        } catch {
                            listError = error
                        }
                    }
                }

                if let error = listError {
                    throw error
                }
            }
        #endif

        // Note: Linux xattr preservation requires C shim for llistxattr/lgetxattr/fsetxattr.
        // These functions are not reliably exposed in Swift's Glibc overlay.
        // Planned for future release with proper C interop target.
    }

    // MARK: - ACL Support

    extension POSIXAtomic {

        /// Copies ACL from source path to destination fd.
        private static func copyACL(
            from srcPath: String,
            to dstFd: Int32
        ) throws(File.System.Write.Atomic.Error) {
            #if ATOMICFILEWRITE_HAS_ACL_SHIMS
                var outErrno: Int32 = 0
                let rc = srcPath.withCString { path in
                    atomicfilewrite_copy_acl_from_path_to_fd(path, dstFd, &outErrno)
                }

                if rc != 0 {
                    // ENOENT means no ACL exists - that's fine
                    if outErrno == ENOENT || outErrno == EOPNOTSUPP || outErrno == ENOTSUP {
                        return
                    }
                    throw .metadataPreservationFailed(
                        operation: "acl_copy",
                        code: .posix(outErrno),
                        message: File.System.Write.Atomic.errorMessage(for: outErrno)
                    )
                }
            #else
                // ACL shims not compiled - silently skip
                // (User requested ACL preservation but it's not available)
                _ = (srcPath, dstFd)
            #endif
        }

        #if ATOMICFILEWRITE_HAS_ACL_SHIMS
            @_silgen_name("atomicfilewrite_copy_acl_from_path_to_fd")
            private static func atomicfilewrite_copy_acl_from_path_to_fd(
                _ srcPath: UnsafePointer<CChar>,
                _ dstFd: Int32,
                _ outErrno: UnsafeMutablePointer<Int32>
            ) -> Int32
        #endif
    }

#endif  // !os(Windows)
