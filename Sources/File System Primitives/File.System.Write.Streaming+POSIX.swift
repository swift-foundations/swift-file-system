// File.System.Write.Streaming+POSIX.swift
// POSIX implementation of streaming file writes (macOS, Linux, BSD)

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

// MARK: - POSIX Implementation

extension File.System.Write.Streaming {
    /// POSIX implementation of streaming file writes (macOS, Linux, BSD).
    public enum POSIX {

        // MARK: - Generic Sequence API

        static func write<Chunks: Sequence>(
        _ chunks: Chunks,
        to path: borrowing String,
        options: borrowing File.System.Write.Streaming.Options
    ) throws(File.System.Write.Streaming.Error)
    where Chunks.Element == [UInt8] {
        
        let resolvedPath = resolvePath(path)
        let parent = parentDirectory(of: resolvedPath)
        try verifyOrCreateParentDirectory(
            parent,
            createIntermediates: options.createIntermediates
        )
        
        switch options.commit {
        case .atomic(let atomicOptions):
            try writeAtomic(chunks, to: resolvedPath, parent: parent, options: atomicOptions)
        case .direct(let directOptions):
            try writeDirect(chunks, to: resolvedPath, options: directOptions)
        }
    }
    
    // MARK: - Atomic Write
    
    private static func writeAtomic<Chunks: Sequence>(
        _ chunks: Chunks,
        to resolvedPath: String,
        parent: String,
        options: File.System.Write.Streaming.Atomic.Options
    ) throws(File.System.Write.Streaming.Error)
    where Chunks.Element == [UInt8] {
        
        // noClobber semantics are enforced by the atomic rename operation
        // (renamex_np with RENAME_EXCL on Darwin, renameat2 with RENAME_NOREPLACE
        // on Linux, or link+unlink fallback). We do NOT pre-check existence here
        // because that would be semantically wrong: noClobber means "don't overwrite
        // if file exists at publish time", not "fail if file exists at start time".
        // A pre-check could cause incorrect early failure if the file is removed
        // between check and publish.
        
        let tempPath = generateTempPath(in: parent, for: resolvedPath)
        let fd = try createFile(at: tempPath, exclusive: true)
        
        var didClose = false
        var didRename = false
        
        defer {
            if !didClose { _ = close(fd) }
            if !didRename { _ = unlink(tempPath) }
        }
        
        // Write all chunks
        for chunk in chunks {
            try writeAll(chunk.span, to: fd, path: resolvedPath)
        }
        
        try syncFile(fd, durability: options.durability)
        try closeFile(fd)
        didClose = true
        
        // Use appropriate rename based on strategy
        switch options.strategy {
        case .replaceExisting:
            try atomicRename(from: tempPath, to: resolvedPath)
        case .noClobber:
            try atomicRenameNoClobber(from: tempPath, to: resolvedPath)
        }
        didRename = true
        
        // Directory sync after publish - only for .full durability.
        // Directory sync is a metadata persistence step, so it should NOT be
        // performed for .dataOnly (which explicitly states "metadata may not
        // be persisted"). If this fails after publish, the file IS published
        // but durability is not guaranteed.
        if options.durability == .full {
            do {
                try syncDirectory(parent)
            } catch let syncError {
                // Extract errno from the sync error for the after-commit error
                if case .directorySyncFailed(let path, let e, let msg) = syncError {
                    throw .directorySyncFailedAfterCommit(
                        path: path,
                        errno: e,
                        message: msg
                    )
                }
                // Shouldn't happen, but rethrow if unexpected error type
                throw syncError
            }
        }
    }
    
    // MARK: - Direct Write
    
    private static func writeDirect<Chunks: Sequence>(
        _ chunks: Chunks,
        to resolvedPath: String,
        options: File.System.Write.Streaming.Direct.Options
    ) throws(File.System.Write.Streaming.Error)
    where Chunks.Element == [UInt8] {
        
        if case .create = options.strategy {
            if fileExists(resolvedPath) {
                throw .destinationExists(path: File.Path(__unchecked: (), resolvedPath))
            }
        }
        
        let fd = try createFile(at: resolvedPath, exclusive: options.strategy == .create)
        
        var didClose = false
        
        defer {
            if !didClose { _ = close(fd) }
        }
        
        // Preallocate if expectedSize is provided (macOS/iOS only)
        // This can improve write throughput by up to 2x for large files
#if canImport(Darwin)
        if let expectedSize = options.expectedSize, expectedSize > 0 {
            preallocate(fd: fd, size: expectedSize)
        }
#endif
        
        // Write all chunks
        for chunk in chunks {
            try writeAll(chunk.span, to: fd, path: resolvedPath)
        }
        
        try syncFile(fd, durability: options.durability)
        try closeFile(fd)
        didClose = true
    }
    }
}

// MARK: - Path Handling

extension File.System.Write.Streaming.POSIX {
    
    private static func resolvePath(_ path: String) -> String {
        var result = path
        
        if result.hasPrefix("~/") {
            if let home = getenv("HOME") {
                result = String(cString: home) + String(result.dropFirst())
            }
        } else if result == "~" {
            if let home = getenv("HOME") {
                result = String(cString: home)
            }
        }
        
        if !result.hasPrefix("/") {
            withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PATH_MAX)) { buffer in
                if getcwd(buffer.baseAddress!, buffer.count) != nil {
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
        
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        
        return result
    }
    
    private static func parentDirectory(of path: String) -> String {
        if path == "/" { return "/" }
        
        guard let lastSlash = path.lastIndex(of: "/") else {
            return "."
        }
        
        if lastSlash == path.startIndex {
            return "/"
        }
        
        return String(path[..<lastSlash])
    }
    
    private static func fileName(of path: String) -> String {
        if let lastSlash = path.lastIndex(of: "/") {
            return String(path[path.index(after: lastSlash)...])
        }
        return path
    }
    
    private static func verifyOrCreateParentDirectory(
        _ dir: String,
        createIntermediates: Bool
    ) throws(File.System.Write.Streaming.Error) {
        do {
            try File.System.Parent.Check.verify(dir, createIntermediates: createIntermediates)
        } catch let e {
            throw .parent(e)
        }
    }
    
    private static func fileExists(_ path: String) -> Bool {
        var st = stat()
        return path.withCString { lstat($0, &st) } == 0
    }
    
    /// Generates temp file path in the same directory as destination.
    ///
    /// Invariant A1: Temp must be in same directory as dest for atomic
    /// operations (especially link+unlink fallback which requires same filesystem).
    private static func generateTempPath(in parent: String, for destPath: String) -> String {
        // Defensive assertion: verify parent matches destPath's actual parent
        // This guards against future refactoring that might pass mismatched values
        let destParent = parentDirectory(of: destPath)
        precondition(
            parent == destParent,
            "Temp file must be in same directory as destination (got parent='\(parent)', destParent='\(destParent)')"
        )
        
        let baseName = fileName(of: destPath)
        let random = randomToken(length: 12)
        return "\(parent)/.\(baseName).streaming.\(random).tmp"
    }
    
    private static func randomToken(length: Int) -> String {
        precondition(length == 12, "randomToken expects fixed length of 12")
        
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer in
            let base = buffer.baseAddress!
            
#if canImport(Darwin)
            arc4random_buf(base, length)
#elseif canImport(Glibc) || canImport(Musl)
            var filled = 0
            while filled < length {
                let result = atomicfilewrite_getrandom(
                    base.advanced(by: filled),
                    length - filled,
                    0
                )
                if result > 0 {
                    filled += Int(result)
                } else if result == -1 {
                    let e = errno
                    if e == EINTR { continue }
                    preconditionFailure("getrandom failed: \(e)")
                }
            }
#endif
            
            return Span(_unsafeElements: buffer).hex.encoded()
        }
    }
}

// MARK: - File Operations

extension File.System.Write.Streaming.POSIX {
    
    private static func createFile(
        at path: String,
        exclusive: Bool
    ) throws(File.System.Write.Streaming.Error) -> Int32 {
        var flags: Int32 = O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC
        if exclusive {
            flags |= O_EXCL
            flags &= ~O_TRUNC  // Don't truncate if exclusive
        }
        let mode: mode_t = 0o644
        
        #if canImport(Darwin)
        let fd = path.withCString { Darwin.open($0, flags, mode) }
        #elseif canImport(Glibc)
        let fd = path.withCString { Glibc.open($0, flags, mode) }
        #elseif canImport(Musl)
        let fd = path.withCString { Musl.open($0, flags, mode) }
        #endif
        
        if fd < 0 {
            let e = errno
            throw .fileCreationFailed(
                path: File.Path(__unchecked: (), path),
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
        
        return fd
    }
    
#if canImport(Darwin)
    /// Preallocates disk space for a file using fcntl(F_PREALLOCATE).
    ///
    /// This reduces APFS metadata updates during sequential writes, improving
    /// throughput by up to 2x for large files. Preallocation is best-effort
    /// reservation only - failures are silently ignored since writes will
    /// still succeed (just slower).
    ///
    /// Note: This does NOT change the file's EOF. The actual file length is
    /// determined by the bytes written. This preserves the semantic that
    /// "file length equals bytes successfully written".
    ///
    /// - Parameters:
    ///   - fd: File descriptor to preallocate for
    ///   - size: Expected total file size in bytes
    private static func preallocate(fd: Int32, size: Int64) {
        // Try contiguous allocation first (best performance)
        var fstore = fstore_t(
            fst_flags: UInt32(F_ALLOCATECONTIG),
            fst_posmode: Int32(F_PEOFPOSMODE),
            fst_offset: 0,
            fst_length: off_t(size),
            fst_bytesalloc: 0
        )
        
        if fcntl(fd, F_PREALLOCATE, &fstore) == -1 {
            // Contiguous failed, try non-contiguous
            fstore.fst_flags = UInt32(F_ALLOCATEALL)
            _ = fcntl(fd, F_PREALLOCATE, &fstore)
        }
        // Do NOT ftruncate - let actual writes determine file length
    }
#endif
    
    /// Writes all bytes to fd, handling partial writes and EINTR.
    private static func writeAll(
        _ span: borrowing Span<UInt8>,
        to fd: Int32,
        path: String
    ) throws(File.System.Write.Streaming.Error) {
        let total = span.count
        if total == 0 { return }
        
        var written = 0
        
        try span.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
            guard let base = buffer.baseAddress else { return }
            
            while written < total {
                let remaining = total - written
                
#if canImport(Darwin)
                let rc = Darwin.write(fd, base.advanced(by: written), remaining)
#elseif canImport(Glibc)
                let rc = Glibc.write(fd, base.advanced(by: written), remaining)
#elseif canImport(Musl)
                let rc = Musl.write(fd, base.advanced(by: written), remaining)
#endif
                
                if rc > 0 {
                    written += rc
                    continue
                }
                
                if rc == 0 {
                    throw File.System.Write.Streaming.Error.writeFailed(
                        path: File.Path(__unchecked: (), path),
                        bytesWritten: written,
                        errno: 0,
                        message: "write returned 0"
                    )
                }
                
                let e = errno
                // Retry on interrupt or would-block
                // Note: EWOULDBLOCK unlikely on regular files but harmless to include
                if e == EINTR || e == EAGAIN || e == EWOULDBLOCK {
                    continue
                }
                
                throw File.System.Write.Streaming.Error.writeFailed(
                    path: File.Path(__unchecked: (), path),
                    bytesWritten: written,
                    errno: e,
                    message: File.System.Write.Streaming.errorMessage(for: e)
                )
            }
        }
    }
    
    private static func syncFile(
        _ fd: Int32,
        durability: File.System.Write.Streaming.Durability
    ) throws(File.System.Write.Streaming.Error) {
        switch durability {
        case .full:
#if canImport(Darwin)
            if fcntl(fd, F_FULLFSYNC) != 0 {
                if fsync(fd) != 0 {
                    let e = errno
                    throw .syncFailed(
                        errno: e,
                        message: File.System.Write.Streaming.errorMessage(for: e)
                    )
                }
            }
#else
            if fsync(fd) != 0 {
                let e = errno
                throw .syncFailed(
                    errno: e,
                    message: File.System.Write.Streaming.errorMessage(for: e)
                )
            }
#endif
            
        case .dataOnly:
#if canImport(Darwin)
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if fcntl(fd, F_BARRIERFSYNC) != 0 {
                if fsync(fd) != 0 {
                    let e = errno
                    throw .syncFailed(
                        errno: e,
                        message: File.System.Write.Streaming.errorMessage(for: e)
                    )
                }
            }
#else
            if fsync(fd) != 0 {
                let e = errno
                throw .syncFailed(
                    errno: e,
                    message: File.System.Write.Streaming.errorMessage(for: e)
                )
            }
#endif
#elseif os(Linux)
            if fdatasync(fd) != 0 {
                let e = errno
                throw .syncFailed(
                    errno: e,
                    message: File.System.Write.Streaming.errorMessage(for: e)
                )
            }
#else
            if fsync(fd) != 0 {
                let e = errno
                throw .syncFailed(
                    errno: e,
                    message: File.System.Write.Streaming.errorMessage(for: e)
                )
            }
#endif
            
        case .none:
            break
        }
    }
    
    /// Closes file descriptor. Does NOT retry on EINTR.
    ///
    /// POSIX close() semantics: if close() returns EINTR, the fd state is
    /// undefined. Retrying could close a different newly-reused fd.
    /// Conservative choice: call once, treat any error as failure.
    private static func closeFile(_ fd: Int32) throws(File.System.Write.Streaming.Error) {
        let rc = close(fd)
        if rc == 0 { return }
        let e = errno
        throw .closeFailed(
            errno: e,
            message: File.System.Write.Streaming.errorMessage(for: e)
        )
    }
    
    private static func atomicRename(
        from: String,
        to: String
    ) throws(File.System.Write.Streaming.Error) {
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
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
    }
    
    /// Atomically renames temp file to destination, failing if destination exists.
    ///
    /// Uses platform-specific atomic mechanisms:
    /// - macOS/iOS: `renamex_np` with `RENAME_EXCL`
    /// - Linux: `renameat2` with `RENAME_NOREPLACE`, fallback to `link+unlink`
    private static func atomicRenameNoClobber(
        from tempPath: String,
        to destPath: String
    ) throws(File.System.Write.Streaming.Error) {
#if canImport(Darwin)
        // macOS/iOS: Use renamex_np with RENAME_EXCL
        // Available since macOS 10.12, iOS 10 (we require newer via Swift 6.2)
        let rc = tempPath.withCString { fromPtr in
            destPath.withCString { toPtr in
                renamex_np(fromPtr, toPtr, UInt32(RENAME_EXCL))
            }
        }
        
        if rc == 0 { return }
        
        let e = errno
        if e == EEXIST {
            throw .destinationExists(path: File.Path(__unchecked: (), destPath))
        }
        throw .renameFailed(
            from: File.Path(__unchecked: (), tempPath),
            to: File.Path(__unchecked: (), destPath),
            errno: e,
            message: File.System.Write.Streaming.errorMessage(for: e)
        )
        
#elseif os(Linux)
        // Linux: Try renameat2 with RENAME_NOREPLACE, fallback to link+unlink
        var outErrno: Int32 = 0
        let rc = tempPath.withCString { fromPtr in
            destPath.withCString { toPtr in
                atomicfilewrite_renameat2_noreplace(fromPtr, toPtr, &outErrno)
            }
        }
        
        if rc == 0 { return }
        
        let e = outErrno
        switch e {
        case EEXIST:
            throw .destinationExists(path: File.Path(__unchecked: (), destPath))
            
        case ENOSYS, EINVAL:
            // ENOSYS: renameat2 not available (old kernel < 3.15)
            // EINVAL: flags not supported by filesystem
            try linkUnlinkFallback(from: tempPath, to: destPath)
            
        case EPERM:
            // EPERM can mean: filesystem rejects RENAME_NOREPLACE, OR real permission error
            // Try fallback, but if that also fails, surface original EPERM with context
            do {
                try linkUnlinkFallback(from: tempPath, to: destPath)
            } catch let fallbackError {
                // Include context that renameat2 returned EPERM before fallback failed
                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    errno: EPERM,
                    message:
                        "renameat2 returned EPERM, fallback also failed: \(fallbackError)"
                )
            }
            
        default:
            throw .renameFailed(
                from: File.Path(__unchecked: (), tempPath),
                to: File.Path(__unchecked: (), destPath),
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
        
#else
        // Other POSIX: Use link+unlink fallback
        try linkUnlinkFallback(from: tempPath, to: destPath)
#endif
    }
    
    /// Fallback noClobber implementation using link()+unlink().
    ///
    /// - `link(temp, dest)` fails with EEXIST if dest exists (atomic check)
    /// - `unlink(temp)` removes the temp name after successful link
    ///
    /// Note: This is NOT identical to rename - it creates a new directory entry
    /// and ctime changes on the inode. But it provides equivalent content atomicity.
    private static func linkUnlinkFallback(
        from tempPath: String,
        to destPath: String
    ) throws(File.System.Write.Streaming.Error) {
        // link() is atomic - fails with EEXIST if dest exists
        let linkRc = tempPath.withCString { fromPtr in
            destPath.withCString { toPtr in
                link(fromPtr, toPtr)
            }
        }
        
        if linkRc != 0 {
            let e = errno
            if e == EEXIST {
                throw .destinationExists(path: File.Path(__unchecked: (), destPath))
            }
            throw .renameFailed(
                from: File.Path(__unchecked: (), tempPath),
                to: File.Path(__unchecked: (), destPath),
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
        
        // Now both temp and dest point to same inode
        // unlink(temp) removes the temp name; dest remains
        let unlinkRc = tempPath.withCString { unlink($0) }
        if unlinkRc != 0 {
            // Unusual but not catastrophic - the write succeeded, dest has correct content
            // We have two names pointing to same data. Log warning but don't throw.
            // (In production, consider logging this condition)
        }
    }
    
    private static func syncDirectory(_ path: String) throws(File.System.Write.Streaming.Error) {
        var flags: Int32 = O_RDONLY | O_CLOEXEC
#if os(Linux)
        flags |= O_DIRECTORY
#endif
        
        #if canImport(Darwin)
        let fd = path.withCString { Darwin.open($0, flags) }
        #elseif canImport(Glibc)
        let fd = path.withCString { Glibc.open($0, flags) }
        #elseif canImport(Musl)
        let fd = path.withCString { Musl.open($0, flags) }
        #endif
        
        if fd < 0 {
            let e = errno
            throw .directorySyncFailed(
                path: File.Path(__unchecked: (), path),
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
        
        defer { _ = close(fd) }
        
        if fsync(fd) != 0 {
            let e = errno
            throw .directorySyncFailed(
                path: File.Path(__unchecked: (), path),
                errno: e,
                message: File.System.Write.Streaming.errorMessage(for: e)
            )
        }
    }
}

// MARK: - Multi-phase Streaming Helpers (for async)

extension File.System.Write.Streaming.POSIX {
    /// Context for multi-phase streaming writes.
    ///
    /// @unchecked Sendable because all fields are immutable value types (Int32, String).
    /// Safe to pass to io.run closures within a single async function.
    public struct Context: @unchecked Sendable {
        public let fd: Int32
        public let tempPath: String?  // nil for direct mode
        public let resolvedPath: String
        public let parent: String
        public let durability: File.System.Write.Streaming.Durability
        public let isAtomic: Bool
        public let strategy: File.System.Write.Streaming.Atomic.Strategy?
    }
}

extension File.System.Write.Streaming.POSIX {
    /// Opens a file for multi-phase streaming write.
    ///
    /// Returns a context that can be used for subsequent write(chunk:) and commit calls.
    public static func open(
        path: String,
        options: File.System.Write.Streaming.Options
    ) throws(File.System.Write.Streaming.Error) -> Context {
        
        let resolvedPath = resolvePath(path)
        let parent = parentDirectory(of: resolvedPath)
        try verifyOrCreateParentDirectory(
            parent,
            createIntermediates: options.createIntermediates
        )
        
        switch options.commit {
        case .atomic(let atomicOptions):
            let tempPath = generateTempPath(in: parent, for: resolvedPath)
            let fd = try createFile(at: tempPath, exclusive: true)
            return Context(
                fd: fd,
                tempPath: tempPath,
                resolvedPath: resolvedPath,
                parent: parent,
                durability: atomicOptions.durability,
                isAtomic: true,
                strategy: atomicOptions.strategy
            )
            
        case .direct(let directOptions):
            // For direct mode with .create strategy, we still need exclusive create
            let fd = try createFile(
                at: resolvedPath,
                exclusive: directOptions.strategy == .create
            )
            return Context(
                fd: fd,
                tempPath: nil,
                resolvedPath: resolvedPath,
                parent: parent,
                durability: directOptions.durability,
                isAtomic: false,
                strategy: nil
            )
        }
    }
    
    /// Writes a chunk to an open streaming context.
    ///
    /// The Span must not escape - callee uses it immediately and synchronously.
    public static func write(
        chunk span: borrowing Span<UInt8>,
        to context: borrowing Context
    ) throws(File.System.Write.Streaming.Error) {
        try writeAll(span, to: context.fd, path: context.tempPath ?? context.resolvedPath)
    }
    
    /// Commits a streaming write, closing the file and performing the atomic rename if needed.
    ///
    /// This function owns post-publish error semantics:
    /// - Pre-publish failures throw normal errors
    /// - Post-publish I/O failures throw `.directorySyncFailedAfterCommit`
    /// - Caller should catch CancellationError after this returns and map to `.durabilityNotGuaranteed`
    ///   if commit had already published (but that requires caller tracking - see note below)
    public static func commit(
        _ context: borrowing Context
    ) throws(File.System.Write.Streaming.Error) {
        
        // Sync file data
        try syncFile(context.fd, durability: context.durability)
        
        // Close the file descriptor
        try closeFile(context.fd)
        
        if context.isAtomic, let tempPath = context.tempPath {
            // Atomic rename
            switch context.strategy {
            case .replaceExisting, .none:
                try atomicRename(from: tempPath, to: context.resolvedPath)
            case .noClobber:
                try atomicRenameNoClobber(from: tempPath, to: context.resolvedPath)
            }
            
            // Directory sync after publish - only for .full durability
            if context.durability == .full {
                do {
                    try syncDirectory(context.parent)
                } catch let syncError {
                    if case .directorySyncFailed(let path, let e, let msg) = syncError {
                        throw .directorySyncFailedAfterCommit(
                            path: path,
                            errno: e,
                            message: msg
                        )
                    }
                    throw syncError
                }
            }
        }
    }
    
    /// Cleans up a failed streaming write.
    ///
    /// Best-effort cleanup - closes fd and removes temp file if atomic mode.
    public static func cleanup(_ context: borrowing Context) {
        // Close fd if still open (ignore errors)
        _ = close(context.fd)
        
        // Remove temp file if atomic mode
        if let tempPath = context.tempPath {
            _ = tempPath.withCString { unlink($0) }
        }
    }
}

#endif  // !os(Windows)
