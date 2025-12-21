// Concatenated export of: File System Primitives
// Generated: Sun Dec 21 11:59:20 CET 2025


// ============================================================
// MARK: - File.Descriptor+POSIX.swift
// ============================================================

//
//  File.Descriptor+POSIX.swift
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

    extension File.Descriptor {
        /// Opens a file using POSIX APIs.
        @usableFromInline
        internal static func _openPOSIX(
            _ path: File.Path,
            mode: Mode,
            options: Options
        ) throws(Error) -> File.Descriptor {
            var flags: Int32 = 0

            // Set access mode
            switch mode {
            case .read:
                flags |= O_RDONLY
            case .write:
                flags |= O_WRONLY
            case .readWrite:
                flags |= O_RDWR
            }

            // Set options
            if options.contains(.create) {
                flags |= O_CREAT
            }
            if options.contains(.truncate) {
                flags |= O_TRUNC
            }
            if options.contains(.exclusive) {
                flags |= O_EXCL
            }
            if options.contains(.append) {
                flags |= O_APPEND
            }
            #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
                if options.contains(.noFollow) {
                    flags |= O_NOFOLLOW
                }
            #endif
            #if canImport(Darwin)
                if options.contains(.closeOnExec) {
                    flags |= O_CLOEXEC
                }
            #elseif canImport(Glibc) || canImport(Musl)
                if options.contains(.closeOnExec) {
                    flags |= O_CLOEXEC
                }
            #endif

            // Default permissions for new files: 0644
            let defaultMode: mode_t = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH

            #if canImport(Darwin)
                let fd = Darwin.open(path.string, flags, defaultMode)
            #elseif canImport(Glibc)
                let fd = Glibc.open(path.string, flags, defaultMode)
            #elseif canImport(Musl)
                let fd = Musl.open(path.string, flags, defaultMode)
            #endif

            guard fd >= 0 else {
                throw _mapErrno(errno, path: path)
            }

            return File.Descriptor(__unchecked: fd)
        }

        /// Maps errno to a descriptor error.
        @usableFromInline
        internal static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EEXIST:
                return .alreadyExists(path)
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
                return .openFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.Descriptor+Windows.swift
// ============================================================

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

// ============================================================
// MARK: - File.Descriptor.swift
// ============================================================

//
//  File.Descriptor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File {
    /// A low-level file descriptor wrapper.
    ///
    /// `File.Descriptor` is a non-copyable type that owns a file descriptor
    /// and ensures it is properly closed when the descriptor goes out of scope.
    ///
    /// This is the core primitive for file I/O. Higher-level types like
    /// `File.Handle` build on top of this.
    ///
    /// ## Example
    /// ```swift
    /// let descriptor = try File.Descriptor.open(path, mode: .read)
    /// defer { try? descriptor.close() }
    /// // use descriptor...
    /// ```
    /// A non-Sendable owning handle. For cross-task usage, either:
    /// - Move into an actor for serialized access
    /// - Use `duplicated()` to create an independent copy
    public struct Descriptor: ~Copyable {
        #if os(Windows)
            @usableFromInline
            internal var _handle: UnsafeSendable<HANDLE?>
        #else
            @usableFromInline
            internal var _fd: Int32
        #endif

        #if os(Windows)
            /// Creates a descriptor from a raw Windows HANDLE.
            @usableFromInline
            internal init(__unchecked handle: HANDLE) {
                self._handle = UnsafeSendable(handle)
            }
        #else
            /// Creates a descriptor from a raw POSIX file descriptor.
            @usableFromInline
            internal init(__unchecked fd: Int32) {
                self._fd = fd
            }
        #endif

        deinit {
            #if os(Windows)
                if let handle = _handle.value, handle != INVALID_HANDLE_VALUE {
                    CloseHandle(handle)
                }
            #else
                if _fd >= 0 {
                    _ = _posixClose(_fd)
                }
            #endif
        }
    }
}

// MARK: - Error

extension File.Descriptor {
    /// Errors that can occur during descriptor operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case isDirectory(File.Path)
        case tooManyOpenFiles
        case invalidDescriptor
        case openFailed(errno: Int32, message: String)
        case closeFailed(errno: Int32, message: String)
        case duplicateFailed(errno: Int32, message: String)
        case alreadyClosed
    }
}

// MARK: - Mode

extension File.Descriptor {
    /// The mode in which to open a file descriptor.
    public enum Mode: Sendable {
        /// Read-only access.
        case read
        /// Write-only access.
        case write
        /// Read and write access.
        case readWrite
    }
}

// MARK: - Options

extension File.Descriptor {
    /// Options for opening a file descriptor.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Create the file if it doesn't exist.
        public static let create = Options(rawValue: 1 << 0)

        /// Truncate the file to zero length if it exists.
        public static let truncate = Options(rawValue: 1 << 1)

        /// Fail if the file already exists (used with `.create`).
        public static let exclusive = Options(rawValue: 1 << 2)

        /// Append to the file.
        public static let append = Options(rawValue: 1 << 3)

        /// Do not follow symbolic links.
        public static let noFollow = Options(rawValue: 1 << 4)

        /// Close the file descriptor on exec.
        public static let closeOnExec = Options(rawValue: 1 << 5)
    }
}

// MARK: - Properties

extension File.Descriptor {
    #if os(Windows)
        /// The raw Windows HANDLE, or `nil` if closed.
        @inlinable
        public var rawHandle: HANDLE? {
            _handle.value
        }

        /// Whether this descriptor is valid (not closed).
        @inlinable
        public var isValid: Bool {
            if let handle = _handle.value {
                return handle != INVALID_HANDLE_VALUE
            }
            return false
        }
    #else
        /// The raw POSIX file descriptor, or -1 if closed.
        @inlinable
        public var rawValue: Int32 {
            _fd
        }

        /// Whether this descriptor is valid (not closed).
        @inlinable
        public var isValid: Bool {
            _fd >= 0
        }
    #endif
}

// MARK: - Core API

extension File.Descriptor {
    /// Opens a file and returns a descriptor.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    /// - Returns: A file descriptor.
    /// - Throws: `File.Descriptor.Error` on failure.
    public static func open(
        _ path: File.Path,
        mode: Mode,
        options: Options = [.closeOnExec]
    ) throws(Error) -> File.Descriptor {
        #if os(Windows)
            return try _openWindows(path, mode: mode, options: options)
        #else
            return try _openPOSIX(path, mode: mode, options: options)
        #endif
    }

    /// Closes the file descriptor.
    ///
    /// After calling this method, the descriptor is invalid and cannot be used.
    /// The descriptor is consumed regardless of whether close succeeds or fails,
    /// preventing double-close scenarios.
    ///
    /// - Throws: `File.Descriptor.Error` on failure.
    public consuming func close() throws(Error) {
        #if os(Windows)
            guard let handle = _handle.value, handle != INVALID_HANDLE_VALUE else {
                throw .alreadyClosed
            }
            // Invalidate first - handle is consumed regardless of CloseHandle result
            // This prevents double-close via deinit if CloseHandle fails
            let handleToClose = handle
            _handle = UnsafeSendable(INVALID_HANDLE_VALUE)
            guard CloseHandle(handleToClose) else {
                let error = GetLastError()
                throw .closeFailed(errno: Int32(error), message: Self._formatWindowsError(error))
            }
        #else
            guard _fd >= 0 else {
                throw .alreadyClosed
            }
            let fd = _fd
            _fd = -1  // Invalidate first - fd is consumed regardless of close() result
            let closeResult = _posixClose(fd)
            guard closeResult == 0 else {
                throw .closeFailed(errno: errno, message: String(cString: strerror(errno)))
            }
        #endif
    }

    /// Creates a file descriptor by duplicating another.
    ///
    /// Creates a new file descriptor that refers to the same open file.
    /// Both descriptors can be used independently and must be closed separately.
    ///
    /// ## Example
    /// ```swift
    /// let original = try File.Descriptor.open(path, mode: .read)
    /// let duplicate = try File.Descriptor(duplicating: original)
    /// // Both can be used independently
    /// ```
    ///
    /// - Parameter other: The file descriptor to duplicate.
    /// - Throws: `File.Descriptor.Error.duplicateFailed` on failure.
    public init(duplicating other: borrowing File.Descriptor) throws(Error) {
        #if os(Windows)
            guard let handle = other._handle.value, handle != INVALID_HANDLE_VALUE else {
                throw .invalidDescriptor
            }

            var duplicateHandle: HANDLE?
            let currentProcess = GetCurrentProcess()

            guard
                _ok(
                    DuplicateHandle(
                        currentProcess,
                        handle,
                        currentProcess,
                        &duplicateHandle,
                        0,
                        false,
                        _dword(DUPLICATE_SAME_ACCESS)
                    )
                )
            else {
                throw .duplicateFailed(
                    errno: Int32(GetLastError()),
                    message: "DuplicateHandle failed"
                )
            }

            guard let newHandle = duplicateHandle else {
                throw .duplicateFailed(errno: 0, message: "DuplicateHandle returned nil")
            }

            self.init(__unchecked: newHandle)
        #else
            guard other._fd >= 0 else {
                throw .invalidDescriptor
            }

            let newFd = dup(other._fd)
            guard newFd >= 0 else {
                throw .duplicateFailed(errno: errno, message: String(cString: strerror(errno)))
            }

            self.init(__unchecked: newFd)
        #endif
    }
}

// MARK: - POSIX Close Helper

#if !os(Windows)
    /// Close a file descriptor with POSIX semantics.
    ///
    /// Treats EINTR as "closed" - the file descriptor is consumed
    /// regardless of whether the kernel completed all cleanup.
    /// This follows the POSIX.1-2008 specification where a descriptor
    /// is always invalid after close(), even if EINTR occurs.
    ///
    /// - Parameter fd: The file descriptor to close.
    /// - Returns: 0 on success, -1 on error (with errno set).
    @inline(__always)
    internal func _posixClose(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
            let result = Darwin.close(fd)
        #else
            let result = close(fd)
        #endif

        // EINTR on close is treated as closed - the fd is now invalid
        // and must not be retried (which would potentially close a recycled fd)
        if result == -1 && errno == EINTR {
            return 0
        }
        return result
    }
#endif

// MARK: - UnsafeSendable Helper

/// A wrapper to make non-Sendable types sendable when we know it's safe.
///
/// ## Safety Invariant (for @unchecked Sendable)
/// The wrapped value must only be accessed from a single isolation context,
/// or the type must be effectively immutable for the duration of concurrent access.
///
/// ### Usage Contract:
/// - Caller is responsible for ensuring thread-safety
/// - Typically used for file descriptors (Int32) which are value types
/// - Do not use for mutable reference types without external synchronization
@usableFromInline
internal struct UnsafeSendable<T>: @unchecked Sendable {
    @usableFromInline
    var value: T

    @usableFromInline
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Binary.Serializable

extension File.Descriptor.Options: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}

extension File.Descriptor.Mode: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .read: return 0
        case .write: return 1
        case .readWrite: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .read
        case 1: self = .write
        case 2: self = .readWrite
        default: return nil
        }
    }
}

extension File.Descriptor.Mode: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.Directory.Contents.swift
// ============================================================

//
//  File.Directory.Contents.swift
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

extension File.Directory {
    /// List directory contents.
    public enum Contents {}
}

// MARK: - Error

extension File.Directory.Contents {
    /// Errors that can occur when listing directory contents.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.Directory.Contents {
    /// Lists the contents of a directory.
    ///
    /// - Parameter path: The path to the directory.
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public static func list(at path: File.Path) throws(Error) -> [File.Directory.Entry] {
        #if os(Windows)
            return try _listWindows(at: path)
        #else
            return try _listPOSIX(at: path)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.Directory.Contents {
        internal static func _listPOSIX(at path: File.Path) throws(Error) -> [File.Directory.Entry]
        {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            // Open directory
            guard let dir = opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }
            defer { closedir(dir) }

            var entries: [File.Directory.Entry] = []

            while let entry = readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-8 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(path, appending: component)
                    location = .absolute(parent: path, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: path)
                }

                // Determine type
                let entryType: File.Directory.Entry.Kind
                #if canImport(Darwin)
                    switch Int32(entry.pointee.d_type) {
                    case DT_REG:
                        entryType = .file
                    case DT_DIR:
                        entryType = .directory
                    case DT_LNK:
                        entryType = .symbolicLink
                    default:
                        entryType = .other
                    }
                #else
                    // Linux/Glibc - trust d_type when available, fallback to lstat only for DT_UNKNOWN
                    // This avoids N syscalls for N files, massive perf improvement for large directories
                    let dtype = Int32(entry.pointee.d_type)
                    if dtype != Int32(DT_UNKNOWN) {
                        switch dtype {
                        case Int32(DT_REG):
                            entryType = .file
                        case Int32(DT_DIR):
                            entryType = .directory
                        case Int32(DT_LNK):
                            entryType = .symbolicLink
                        default:
                            entryType = .other
                        }
                    } else {
                        // Filesystem doesn't support d_type (e.g., some network filesystems)
                        // Fall back to lstat for this entry (need path for this)
                        if let entryPath = location.path {
                            var entryStat = stat()
                            if lstat(entryPath.string, &entryStat) == 0 {
                                switch entryStat.st_mode & S_IFMT {
                                case S_IFREG:
                                    entryType = .file
                                case S_IFDIR:
                                    entryType = .directory
                                case S_IFLNK:
                                    entryType = .symbolicLink
                                default:
                                    entryType = .other
                                }
                            } else {
                                entryType = .other
                            }
                        } else {
                            // Cannot lstat undecodable path - mark as other
                            entryType = .other
                        }
                    }
                #endif

                entries.append(File.Directory.Entry(name: name, location: location, type: entryType))
            }

            return entries
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOTDIR:
                return .notADirectory(path)
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
    extension File.Directory.Contents {
        internal static func _listWindows(
            at path: File.Path
        ) throws(Error) -> [File.Directory.Entry] {
            // Verify it's a directory
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                throw .pathNotFound(path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 else {
                throw .notADirectory(path)
            }

            var entries: [File.Directory.Entry] = []
            var findData = WIN32_FIND_DATAW()
            let searchPath = path.string + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { FindClose(handle) }

            repeat {
                let name = File.Name(windowsDirectoryEntryName: findData.cFileName)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-16 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(path, appending: component)
                    location = .absolute(parent: path, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: path)
                }

                // Determine type
                let entryType: File.Directory.Entry.Kind
                if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    entryType = .directory
                } else if (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                    // Conservative classification: reparse points include junctions,
                    // mount points, OneDrive placeholders, etc. - not just symlinks
                    entryType = .other
                } else {
                    entryType = .file
                }

                entries.append(File.Directory.Entry(name: name, location: location, type: entryType))
            } while _ok(FindNextFileW(handle, &findData))

            let lastError = GetLastError()
            if lastError != _dword(ERROR_NO_MORE_FILES) {
                throw _mapWindowsError(lastError, path: path)
            }

            return entries
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

extension File.Directory.Contents.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.Directory.Entry.Location.swift
// ============================================================

//
//  File.Directory.Entry.Location.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Entry {
    /// The location of a directory entry.
    ///
    /// Both cases store parent explicitly - no computed fallback needed.
    /// This ensures the parent is always available regardless of whether
    /// the name could be decoded to a String.
    ///
    /// ## Cases
    /// - `.absolute(parent:path:)`: Name was successfully decoded to String.
    ///   Both parent and full path are stored explicitly.
    /// - `.relative(parent:)`: Name could not be decoded (invalid UTF-8/UTF-16
    ///   or contains invalid path characters). Only parent is available;
    ///   use `Entry.name` for raw filesystem operations.
    public enum Location: Sendable, Equatable {
        /// Absolute path - name was successfully decoded to String.
        ///
        /// Parent is stored explicitly (no fallback computation).
        case absolute(parent: File.Path, path: File.Path)

        /// Relative reference - name could not be decoded.
        ///
        /// Use the parent path and raw `Entry.name` for operations.
        case relative(parent: File.Path)
    }
}

// MARK: - Convenience Accessors

extension File.Directory.Entry.Location {
    /// The parent directory path. Always available.
    @inlinable
    public var parent: File.Path {
        switch self {
        case .absolute(let parent, _): return parent
        case .relative(let parent): return parent
        }
    }

    /// The absolute path, if the name was decodable.
    ///
    /// Returns `nil` for `.relative` locations where the name could not
    /// be decoded to a valid String.
    @inlinable
    public var path: File.Path? {
        switch self {
        case .absolute(_, let path): return path
        case .relative: return nil
        }
    }
}

// ============================================================
// MARK: - File.Directory.Entry.Type.swift
// ============================================================

//
//  File.Directory.Entry.Kind.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Directory.Entry {
    /// The type of a directory entry.
    public enum Kind: Sendable {
        /// A regular file.
        case file
        /// A directory (folder).
        case directory
        /// A symbolic link pointing to another path.
        case symbolicLink
        /// Block device, character device, socket, FIFO, or unknown type.
        case other
    }
}

// MARK: - RawRepresentable

extension File.Directory.Entry.Kind: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .file: return 0
        case .directory: return 1
        case .symbolicLink: return 2
        case .other: return 3
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .file
        case 1: self = .directory
        case 2: self = .symbolicLink
        case 3: self = .other
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Directory.Entry.Kind: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.Directory.Entry.swift
// ============================================================

//
//  File.Directory.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory {
    /// A directory entry representing a file or subdirectory.
    public struct Entry: Sendable {
        /// The name of the entry.
        ///
        /// Uses `File.Name` to preserve raw filesystem encoding. Use `String(entry.name)`
        /// for strict decoding, or `String(lossy: entry.name)` for a guaranteed (but
        /// potentially lossy) string representation.
        public let name: File.Name

        /// The location of the entry.
        ///
        /// Contains either an absolute path (if name was decodable) or a relative
        /// reference to the parent directory (if name could not be decoded).
        public let location: Location

        /// The type of the entry.
        public let type: Kind

        /// Creates a directory entry.
        ///
        /// - Parameters:
        ///   - name: The entry's filename (raw bytes preserved).
        ///   - location: The location of the entry (absolute or relative).
        ///   - type: The type of entry (file, directory, symlink, etc.).
        public init(name: File.Name, location: Location, type: Kind) {
            self.name = name
            self.location = location
            self.type = type
        }
    }
}

// MARK: - Convenience Accessors

extension File.Directory.Entry {
    /// The absolute path, if the name was decodable.
    ///
    /// Returns `nil` if the entry has a `.relative` location (name could not be decoded).
    @inlinable
    public var path: File.Path? { location.path }

    /// The parent directory path. Always available.
    @inlinable
    public var parent: File.Path { location.parent }
}

// ============================================================
// MARK: - File.Directory.Iterator.swift
// ============================================================

//
//  File.Directory.Iterator.swift
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

extension File.Directory {
    /// A streaming directory iterator that yields entries one at a time.
    ///
    /// This is a ~Copyable type that owns the underlying directory handle
    /// and closes it when done.
    ///
    /// ## Thread Safety
    /// `Iterator` is **NOT** `Sendable`. It owns mutable state (the directory handle)
    /// and is not safe for concurrent use. For cross-task usage, wrap in an actor
    /// or use the async layer.
    public struct Iterator: ~Copyable /* NOT Sendable - owns mutable directory handle */ {
        #if os(Windows)
            private var _handle: HANDLE?
            private var _findData: WIN32_FIND_DATAW
            private var _hasMore: Bool
        #elseif canImport(Darwin)
            private var _dir: UnsafeMutablePointer<DIR>?
        #elseif canImport(Glibc)
            // Use OpaquePointer on Linux (DIR type not exported in Swift's Glibc overlay)
            private var _dir: OpaquePointer?
        #elseif canImport(Musl)
            // Use OpaquePointer on Musl (same as Glibc)
            private var _dir: OpaquePointer?
        #endif
        private let _basePath: File.Path

        deinit {
            #if os(Windows)
                if let handle = _handle, handle != INVALID_HANDLE_VALUE {
                    FindClose(handle)
                }
            #elseif canImport(Darwin)
                if let dir = _dir {
                    closedir(dir)
                }
            #elseif canImport(Glibc)
                if let dir = _dir {
                    Glibc.closedir(dir)
                }
            #elseif canImport(Musl)
                if let dir = _dir {
                    Musl.closedir(dir)
                }
            #endif
        }
    }
}

// MARK: - Error

extension File.Directory.Iterator {
    /// Errors that can occur during iteration.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.Directory.Iterator {
    /// Opens a directory for iteration.
    ///
    /// - Parameter path: The path to the directory.
    /// - Returns: An iterator for the directory.
    /// - Throws: `File.Directory.Iterator.Error` on failure.
    public static func open(at path: File.Path) throws(Error) -> File.Directory.Iterator {
        #if os(Windows)
            return try _openWindows(at: path)
        #else
            return try _openPOSIX(at: path)
        #endif
    }

    /// Returns the next entry in the directory, or nil if done.
    ///
    /// - Returns: The next directory entry, or nil if iteration is complete.
    /// - Throws: `File.Directory.Iterator.Error` on failure.
    public mutating func next() throws(Error) -> File.Directory.Entry? {
        #if os(Windows)
            return try _nextWindows()
        #else
            return try _nextPOSIX()
        #endif
    }

    /// Closes the iterator and releases resources.
    public consuming func close() {
        #if os(Windows)
            if let handle = _handle, handle != INVALID_HANDLE_VALUE {
                FindClose(handle)
                _handle = INVALID_HANDLE_VALUE
            }
        #elseif canImport(Darwin)
            if let dir = _dir {
                closedir(dir)
                _dir = nil
            }
        #elseif canImport(Glibc)
            if let dir = _dir {
                Glibc.closedir(dir)
                _dir = nil
            }
        #elseif canImport(Musl)
            if let dir = _dir {
                Musl.closedir(dir)
                _dir = nil
            }
        #endif
    }
}

// MARK: - POSIX Implementation

#if canImport(Darwin)
    extension File.Directory.Iterator {
        private static func _openPOSIX(at path: File.Path) throws(Error) -> File.Directory.Iterator
        {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            guard let dir = opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }

            return File.Directory.Iterator(
                _dir: dir,
                _basePath: path
            )
        }

        private mutating func _nextPOSIX() throws(Error) -> File.Directory.Entry? {
            guard let dir = _dir else {
                return nil
            }

            while let entry = readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-8 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(_basePath, appending: component)
                    location = .absolute(parent: _basePath, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: _basePath)
                }

                // Determine type - use lstat fallback for DT_UNKNOWN
                let entryType: File.Directory.Entry.Kind
                switch Int32(entry.pointee.d_type) {
                case DT_REG:
                    entryType = .file
                case DT_DIR:
                    entryType = .directory
                case DT_LNK:
                    entryType = .symbolicLink
                case DT_UNKNOWN:
                    // Fallback to lstat for unknown type (need path for this)
                    if let path = location.path {
                        var entryStat = stat()
                        if lstat(path.string, &entryStat) == 0 {
                            switch entryStat.st_mode & S_IFMT {
                            case S_IFREG:
                                entryType = .file
                            case S_IFDIR:
                                entryType = .directory
                            case S_IFLNK:
                                entryType = .symbolicLink
                            default:
                                entryType = .other
                            }
                        } else {
                            entryType = .other
                        }
                    } else {
                        // Cannot lstat undecodable path - mark as other
                        entryType = .other
                    }
                default:
                    entryType = .other
                }

                return File.Directory.Entry(name: name, location: location, type: entryType)
            }

            return nil
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOTDIR:
                return .notADirectory(path)
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
#elseif canImport(Glibc)
    extension File.Directory.Iterator {
        private static func _openPOSIX(at path: File.Path) throws(Error) -> File.Directory.Iterator
        {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            guard let dir = Glibc.opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }

            return File.Directory.Iterator(
                _dir: dir,
                _basePath: path
            )
        }

        private mutating func _nextPOSIX() throws(Error) -> File.Directory.Entry? {
            guard let dir = _dir else {
                return nil
            }

            while let entry = Glibc.readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-8 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(_basePath, appending: component)
                    location = .absolute(parent: _basePath, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: _basePath)
                }

                // Determine type via lstat (Glibc doesn't reliably expose d_type)
                let entryType: File.Directory.Entry.Kind
                if let path = location.path {
                    var entryStat = stat()
                    if Glibc.lstat(path.string, &entryStat) == 0 {
                        switch entryStat.st_mode & S_IFMT {
                        case S_IFREG:
                            entryType = .file
                        case S_IFDIR:
                            entryType = .directory
                        case S_IFLNK:
                            entryType = .symbolicLink
                        default:
                            entryType = .other
                        }
                    } else {
                        entryType = .other
                    }
                } else {
                    // Cannot lstat undecodable path - mark as other
                    entryType = .other
                }

                return File.Directory.Entry(name: name, location: location, type: entryType)
            }

            return nil
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOTDIR:
                return .notADirectory(path)
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

#elseif canImport(Musl)
    extension File.Directory.Iterator {
        private static func _openPOSIX(at path: File.Path) throws(Error) -> File.Directory.Iterator
        {
            // Verify it's a directory
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(path)
            }

            guard let dir = Musl.opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }

            return File.Directory.Iterator(
                _dir: dir,
                _basePath: path
            )
        }

        private mutating func _nextPOSIX() throws(Error) -> File.Directory.Entry? {
            guard let dir = _dir else {
                return nil
            }

            while let entry = Musl.readdir(dir) {
                let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-8 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(_basePath, appending: component)
                    location = .absolute(parent: _basePath, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: _basePath)
                }

                // Determine type via lstat (Musl doesn't reliably expose d_type)
                let entryType: File.Directory.Entry.Kind
                if let path = location.path {
                    var entryStat = stat()
                    if Musl.lstat(path.string, &entryStat) == 0 {
                        switch entryStat.st_mode & S_IFMT {
                        case S_IFREG:
                            entryType = .file
                        case S_IFDIR:
                            entryType = .directory
                        case S_IFLNK:
                            entryType = .symbolicLink
                        default:
                            entryType = .other
                        }
                    } else {
                        entryType = .other
                    }
                } else {
                    // Cannot lstat undecodable path - mark as other
                    entryType = .other
                }

                return File.Directory.Entry(name: name, location: location, type: entryType)
            }

            return nil
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOTDIR:
                return .notADirectory(path)
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
    extension File.Directory.Iterator {
        private static func _openWindows(
            at path: File.Path
        ) throws(Error) -> File.Directory.Iterator {
            // Verify it's a directory
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                // CRITICAL: Read GetLastError() immediately
                throw _mapWindowsError(GetLastError(), path: path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 else {
                throw .notADirectory(path)
            }

            var findData = WIN32_FIND_DATAW()
            let searchPath = path.string + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            return File.Directory.Iterator(
                _handle: handle,
                _findData: findData,
                _hasMore: true,
                _basePath: path
            )
        }

        private mutating func _nextWindows() throws(Error) -> File.Directory.Entry? {
            guard let handle = _handle, handle != INVALID_HANDLE_VALUE, _hasMore else {
                return nil
            }

            while true {
                // Snapshot current entry BEFORE any advancement
                let currentFindData = _findData
                let name = File.Name(windowsDirectoryEntryName: currentFindData.cFileName)
                let attributes = currentFindData.dwFileAttributes

                // Advance to next entry for next iteration
                // CRITICAL: Read GetLastError() immediately - no intervening WinAPI calls
                if !_ok(FindNextFileW(handle, &_findData)) {
                    let err = GetLastError()
                    if err == _dword(ERROR_NO_MORE_FILES) {
                        _hasMore = false
                    } else {
                        // Actual error occurred during iteration
                        throw _mapWindowsError(err, path: _basePath)
                    }
                }

                // Skip . and .. using raw byte comparison (no decoding)
                if name.isDotOrDotDot {
                    if !_hasMore { return nil }
                    continue
                }

                // Construct location - strict, using File.Path.Component for validation
                let location: File.Directory.Entry.Location
                if let nameString = String(name),
                   let component = try? File.Path.Component(nameString) {
                    // Valid UTF-16 AND valid path component (no separators, etc.)
                    let entryPath = File.Path(_basePath, appending: component)
                    location = .absolute(parent: _basePath, path: entryPath)
                } else {
                    // Either decoding failed OR contains invalid characters (separators)
                    location = .relative(parent: _basePath)
                }

                // Determine type from SNAPSHOT attributes (not current _findData)
                let entryType: File.Directory.Entry.Kind
                if (attributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    entryType = .directory
                } else if (attributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                    // Conservative classification: reparse points include junctions,
                    // mount points, OneDrive placeholders, etc. - not just symlinks
                    entryType = .other
                } else {
                    entryType = .file
                }

                return File.Directory.Entry(name: name, location: location, type: entryType)
            }
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

extension File.Directory.Iterator.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.Directory.Walk.Undecodable.Context.swift
// ============================================================

//
//  File.Directory.Walk.Undecodable.Context.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk.Undecodable {
    /// Context provided when an undecodable entry is encountered during walk.
    ///
    /// This context allows the callback to make an informed decision about
    /// how to handle the entry, and provides access to raw name bytes for
    /// diagnostics or logging.
    public struct Context: Sendable {
        /// The parent directory (which is decodable).
        public let parent: File.Path

        /// The undecodable entry name (raw bytes/code units preserved).
        ///
        /// Use `name.debugDescription` for logging or `String(lossy: name)`
        /// for a best-effort string representation.
        public let name: File.Name

        /// The type of the entry.
        public let type: File.Directory.Entry.Kind

        /// Current depth in the walk (0 = root directory).
        public let depth: Int

        /// Creates an undecodable context.
        ///
        /// - Parameters:
        ///   - parent: The parent directory path.
        ///   - name: The undecodable entry name.
        ///   - type: The type of the entry.
        ///   - depth: Current depth in the walk.
        public init(
            parent: File.Path,
            name: File.Name,
            type: File.Directory.Entry.Kind,
            depth: Int
        ) {
            self.parent = parent
            self.name = name
            self.type = type
            self.depth = depth
        }
    }
}

// ============================================================
// MARK: - File.Directory.Walk.Undecodable.Policy.swift
// ============================================================

//
//  File.Directory.Walk.Undecodable.Policy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk.Undecodable {
    /// Policy for handling entries with undecodable names during directory walk.
    ///
    /// ## Semantics
    /// - `.skip`: Do NOT emit entry, do NOT descend into directory
    /// - `.emit`: Emit entry (with `.relative` location), do NOT descend into directory
    /// - `.stopAndThrow`: Stop the walk and throw an error with context
    ///
    /// ## Usage
    /// ```swift
    /// let options = File.Directory.Walk.Options(
    ///     onUndecodable: { context in
    ///         print("Found undecodable entry: \(context.name.debugDescription)")
    ///         return .emit  // Include it but don't descend
    ///     }
    /// )
    /// ```
    public enum Policy: Sendable {
        /// Skip entirely - do not emit, do not descend.
        ///
        /// The entry will not appear in walk results. If it's a directory,
        /// its contents will not be traversed.
        case skip

        /// Emit the entry with relative location, but do not descend.
        ///
        /// The entry will appear in walk results with a `.relative(parent:)` location.
        /// If it's a directory, its contents will not be traversed (since we cannot
        /// construct a valid path to descend into).
        case emit

        /// Stop the walk and throw an error.
        ///
        /// The walk will terminate immediately with an `undecodableEntry` error
        /// containing the parent path and raw name.
        case stopAndThrow
    }
}

// ============================================================
// MARK: - File.Directory.Walk.Undecodable.swift
// ============================================================

//
//  File.Directory.Walk.Undecodable.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk {
    /// Namespace for handling entries with undecodable names during directory walk.
    ///
    /// When traversing directories, some filenames may contain byte sequences
    /// that cannot be decoded to valid UTF-8 (POSIX) or UTF-16 (Windows).
    /// This namespace provides types to handle such entries.
    public enum Undecodable {}
}

// ============================================================
// MARK: - File.Directory.Walk.swift
// ============================================================

//
//  File.Directory.Walk.swift
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

extension File.Directory {
    /// Recursive directory traversal.
    public enum Walk {}
}

// MARK: - Options

extension File.Directory.Walk {
    /// Options for directory traversal.
    public struct Options: Sendable {
        /// Maximum depth to traverse (nil for unlimited).
        public var maxDepth: Int?

        /// Whether to follow symbolic links.
        public var followSymlinks: Bool

        /// Whether to include hidden files.
        public var includeHidden: Bool

        /// Callback invoked when an entry with an undecodable name is encountered.
        ///
        /// Default: `.skip` (do not emit, do not descend).
        public var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy

        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true,
            onUndecodable: @escaping @Sendable (Undecodable.Context) -> Undecodable.Policy = { _ in .skip }
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
            self.onUndecodable = onUndecodable
        }
    }
}

// MARK: - Error

extension File.Directory.Walk {
    /// Errors that can occur during directory walk operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: String)
        case undecodableEntry(parent: File.Path, name: File.Name)
    }
}

// MARK: - Core API

extension File.Directory.Walk {
    /// Recursively walks a directory and returns all entries.
    ///
    /// - Parameters:
    ///   - path: The root directory to walk.
    ///   - options: Walk options.
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public static func walk(
        at path: File.Path,
        options: Options = Options()
    ) throws(Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        try _walk(at: path, options: options, depth: 0, entries: &entries)
        return entries
    }

}

// MARK: - Implementation

extension File.Directory.Walk {
    private static func _walk(
        at path: File.Path,
        options: Options,
        depth: Int,
        entries: inout [File.Directory.Entry]
    ) throws(Error) {
        // Check depth limit
        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }

        // List directory contents
        let contents: [File.Directory.Entry]
        do {
            contents = try File.Directory.Contents.list(at: path)
        } catch let error {
            switch error {
            case .pathNotFound(let p):
                throw .pathNotFound(p)
            case .permissionDenied(let p):
                throw .permissionDenied(p)
            case .notADirectory(let p):
                throw .notADirectory(p)
            case .readFailed(let errno, let message):
                throw .walkFailed(errno: errno, message: message)
            }
        }

        for entry in contents {
            // Filter hidden files using semantic predicate (no raw access)
            if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                continue
            }

            // Check if undecodable BEFORE appending
            switch entry.location {
            case .absolute(_, let entryPath):
                // Decodable - emit and recurse if directory
                entries.append(entry)

                if entry.type == .directory {
                    try _walk(at: entryPath, options: options, depth: depth + 1, entries: &entries)
                } else if entry.type == .symbolicLink && options.followSymlinks {
                    // Check if symlink points to a directory (follows symlink via stat)
                    if let info = try? File.System.Stat.info(at: entryPath),
                        info.type == .directory
                    {
                        try _walk(at: entryPath, options: options, depth: depth + 1, entries: &entries)
                    }
                }

            case .relative(let parent):
                // Undecodable - invoke callback to decide
                let context = Undecodable.Context(
                    parent: parent,
                    name: entry.name,
                    type: entry.type,
                    depth: depth
                )
                switch options.onUndecodable(context) {
                case .skip:
                    continue  // Do not emit, do not descend
                case .emit:
                    entries.append(entry)  // Emit with relative location, do not descend
                case .stopAndThrow:
                    throw .undecodableEntry(parent: parent, name: entry.name)
                }
            }
        }
    }
}

// MARK: - CustomStringConvertible for Error

extension File.Directory.Walk.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .walkFailed(let errno, let message):
            return "Walk failed: \(message) (errno=\(errno))"
        case .undecodableEntry(let parent, let name):
            return "Undecodable entry in \(parent): \(name.debugDescription)"
        }
    }
}

// ============================================================
// MARK: - File.Directory.swift
// ============================================================

//
//  File.Directory.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File {
    /// A directory reference providing convenient access to directory operations.
    ///
    /// `File.Directory` wraps a path and provides ergonomic methods that
    /// delegate to `File.System.*` primitives. It is Hashable and Sendable.
    ///
    /// ## Example
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    /// try dir.create(withIntermediates: true)
    /// let readme = dir[file: "README.md"]
    ///
    /// for entry in try dir.contents() {
    ///     print(entry.name)
    /// }
    /// ```
    public struct Directory: Hashable, Sendable {
        /// The underlying directory path.
        public let path: File.Path

        // MARK: - Initializers

        /// Creates a directory from a path.
        ///
        /// - Parameter path: The directory path.
        public init(_ path: File.Path) {
            self.path = path
        }

        /// Creates a directory from a string path.
        ///
        /// - Parameter string: The path string.
        /// - Throws: `File.Path.Error` if the path is invalid.
        public init(_ string: String) throws {
            self.path = try File.Path(string)
        }
    }
}

// ============================================================
// MARK: - File.Handle.Mode.swift
// ============================================================

//
//  File.Handle.Mode.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Handle {
    /// The mode in which a file handle was opened.
    public enum Mode: Sendable {
        /// Read-only access.
        case read
        /// Write-only access.
        case write
        /// Read and write access.
        case readWrite
        /// Append-only access.
        case append
    }
}

// MARK: - RawRepresentable

extension File.Handle.Mode: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .read: return 0
        case .write: return 1
        case .readWrite: return 2
        case .append: return 3
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .read
        case 1: self = .write
        case 2: self = .readWrite
        case 3: self = .append
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Handle.Mode: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.Handle.Options.swift
// ============================================================

//
//  File.Handle.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.Handle {
    /// Options for opening a file handle.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Create the file if it doesn't exist.
        public static let create = Options(rawValue: 1 << 0)

        /// Truncate the file to zero length if it exists.
        public static let truncate = Options(rawValue: 1 << 1)

        /// Fail if the file already exists (used with `.create`).
        public static let exclusive = Options(rawValue: 1 << 2)

        /// Do not follow symbolic links.
        public static let noFollow = Options(rawValue: 1 << 3)

        /// Close the file descriptor on exec.
        public static let closeOnExec = Options(rawValue: 1 << 4)
    }
}

// MARK: - Binary.Serializable

extension File.Handle.Options: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}

// ============================================================
// MARK: - File.Handle.swift
// ============================================================

//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File {
    /// A managed file handle for reading and writing.
    ///
    /// `File.Handle` is a non-copyable type that owns a file descriptor
    /// along with metadata about how the file was opened. It provides
    /// read, write, and seek operations.
    ///
    /// ## Example
    /// ```swift
    /// var handle = try File.Handle.open(path, mode: .readWrite)
    /// try handle.write(bytes)
    /// try handle.seek(to: 0)
    /// let data = try handle.read(count: 100)
    /// handle.close()
    /// ```
    /// A non-Sendable owning handle. For cross-task usage, move into an actor.
    public struct Handle: ~Copyable {
        /// The underlying file descriptor.
        private var _descriptor: File.Descriptor
        /// The mode this handle was opened with.
        public let mode: Mode
        /// The path this handle was opened for.
        public let path: File.Path

        /// Creates a handle from an existing descriptor.
        internal init(descriptor: consuming File.Descriptor, mode: Mode, path: File.Path) {
            self._descriptor = descriptor
            self.mode = mode
            self.path = path
        }
    }
}

// MARK: - Error

extension File.Handle {
    /// Errors that can occur during handle operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case isDirectory(File.Path)
        case invalidHandle
        case alreadyClosed
        case seekFailed(errno: Int32, message: String)
        case readFailed(errno: Int32, message: String)
        case writeFailed(errno: Int32, message: String)
        case closeFailed(errno: Int32, message: String)
        case openFailed(errno: Int32, message: String)
    }
}

// MARK: - SeekOrigin

extension File.Handle {
    /// The origin for seek operations.
    public enum SeekOrigin: Sendable {
        /// Seek from the beginning of the file.
        case start
        /// Seek from the current position.
        case current
        /// Seek from the end of the file.
        case end
    }
}

// MARK: - Core API

extension File.Handle {
    /// Opens a file and returns a handle.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    /// - Returns: A file handle.
    /// - Throws: `File.Handle.Error` on failure.
    public static func open(
        _ path: File.Path,
        mode: Mode,
        options: Options = [.closeOnExec]
    ) throws(Error) -> File.Handle {
        let descriptorMode: File.Descriptor.Mode
        var descriptorOptions: File.Descriptor.Options = []

        switch mode {
        case .read:
            descriptorMode = .read
        case .write:
            descriptorMode = .write
        case .readWrite:
            descriptorMode = .readWrite
        case .append:
            descriptorMode = .write
            descriptorOptions.insert(.append)
        }

        if options.contains(.create) {
            descriptorOptions.insert(.create)
        }
        if options.contains(.truncate) {
            descriptorOptions.insert(.truncate)
        }
        if options.contains(.exclusive) {
            descriptorOptions.insert(.exclusive)
        }
        if options.contains(.noFollow) {
            descriptorOptions.insert(.noFollow)
        }
        if options.contains(.closeOnExec) {
            descriptorOptions.insert(.closeOnExec)
        }

        let descriptor: File.Descriptor
        do {
            descriptor = try File.Descriptor.open(
                path,
                mode: descriptorMode,
                options: descriptorOptions
            )
        } catch let error {
            switch error {
            case .pathNotFound(let p):
                throw .pathNotFound(p)
            case .permissionDenied(let p):
                throw .permissionDenied(p)
            case .alreadyExists(let p):
                throw .alreadyExists(p)
            case .isDirectory(let p):
                throw .isDirectory(p)
            case .openFailed(let errno, let message):
                throw .openFailed(errno: errno, message: message)
            default:
                throw .openFailed(errno: 0, message: "\(error)")
            }
        }

        return File.Handle(descriptor: descriptor, mode: mode, path: path)
    }

    /// Reads up to `count` bytes from the file.
    ///
    /// This is a single-syscall primitive. It returns whatever bytes are available
    /// up to `count`, which may be fewer than requested even before EOF.
    /// Callers who need exactly `count` bytes should loop or use `Read.Full`.
    ///
    /// - Parameter count: Maximum number of bytes to read.
    /// - Returns: The bytes read (may be fewer than requested at EOF or partial read).
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func read(count: Int) throws(Error) -> [UInt8] {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }
        guard count > 0 else { return [] }

        #if os(Windows)
            // Validate count fits in DWORD to avoid truncation bug
            guard count <= Int(DWORD.max) else {
                throw .readFailed(
                    errno: Int32(ERROR_INVALID_PARAMETER),
                    message: "count exceeds DWORD.max"
                )
            }
        #endif

        // Capture error state from non-throwing closure
        var readError: Error? = nil

        let buffer = [UInt8](unsafeUninitializedCapacity: count) { buffer, initializedCount in
            guard let base = buffer.baseAddress else {
                initializedCount = 0
                return
            }

            #if os(Windows)
                var bytesRead: DWORD = 0
                guard let handle = _descriptor.rawHandle else {
                    readError = .invalidHandle
                    initializedCount = 0
                    return
                }
                if !_ok(ReadFile(handle, base, DWORD(count), &bytesRead, nil)) {
                    readError = .readFailed(
                        errno: Int32(GetLastError()),
                        message: "ReadFile failed"
                    )
                    initializedCount = 0
                    return
                }
                initializedCount = Int(bytesRead)

            #elseif canImport(Darwin)
                let result = Darwin.read(_descriptor.rawValue, base, count)
                if result < 0 {
                    let e = errno
                    readError = .readFailed(errno: e, message: String(cString: strerror(e)))
                    initializedCount = 0
                    return
                }
                initializedCount = result

            #elseif canImport(Glibc)
                let result = Glibc.read(_descriptor.rawValue, base, count)
                if result < 0 {
                    let e = errno
                    readError = .readFailed(errno: e, message: String(cString: strerror(e)))
                    initializedCount = 0
                    return
                }
                initializedCount = result

            #elseif canImport(Musl)
                let result = Musl.read(_descriptor.rawValue, base, count)
                if result < 0 {
                    let e = errno
                    readError = .readFailed(errno: e, message: String(cString: strerror(e)))
                    initializedCount = 0
                    return
                }
                initializedCount = result
            #endif
        }

        if let error = readError {
            throw error
        }
        return buffer
    }

    /// Reads bytes into a caller-provided buffer.
    ///
    /// This is the canonical zero-allocation read API. Callers provide the destination buffer.
    ///
    /// - Parameter buffer: Destination buffer. Must remain valid for duration of call.
    /// - Returns: Number of bytes read (0 at EOF).
    /// - Note: May return fewer bytes than buffer size (partial read).
    public mutating func read(into buffer: UnsafeMutableRawBufferPointer) throws(Error) -> Int {
        guard _descriptor.isValid else { throw .invalidHandle }
        guard !buffer.isEmpty else { return 0 }

        #if os(Windows)
            var bytesRead: DWORD = 0
            guard
                _ok(
                    ReadFile(
                        _descriptor.rawHandle!,
                        buffer.baseAddress,
                        DWORD(truncatingIfNeeded: buffer.count),
                        &bytesRead,
                        nil
                    )
                )
            else {
                throw .readFailed(errno: Int32(GetLastError()), message: "ReadFile failed")
            }
            return Int(bytesRead)
        #elseif canImport(Darwin)
            let result = Darwin.read(_descriptor.rawValue, buffer.baseAddress!, buffer.count)
            if result < 0 {
                throw .readFailed(errno: errno, message: String(cString: strerror(errno)))
            }
            return result
        #elseif canImport(Glibc)
            let result = Glibc.read(_descriptor.rawValue, buffer.baseAddress!, buffer.count)
            if result < 0 {
                throw .readFailed(errno: errno, message: String(cString: strerror(errno)))
            }
            return result
        #elseif canImport(Musl)
            let result = Musl.read(_descriptor.rawValue, buffer.baseAddress!, buffer.count)
            if result < 0 {
                throw .readFailed(errno: errno, message: String(cString: strerror(errno)))
            }
            return result
        #endif
    }

    /// Writes bytes to the file.
    ///
    /// - Parameter bytes: The bytes to write.
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func write(_ bytes: borrowing Span<UInt8>) throws(Error) {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        let count = bytes.count
        if count == 0 { return }

        try bytes.withUnsafeBufferPointer { buffer throws(Error) in
            guard let base = buffer.baseAddress else { return }

            #if os(Windows)
                // Loop for partial writes - WriteFile may return fewer bytes than requested
                var totalWritten: Int = 0
                while totalWritten < count {
                    var written: DWORD = 0
                    let remaining = count - totalWritten
                    let ptr = base.advanced(by: totalWritten)
                    let success = _ok(
                        WriteFile(
                            _descriptor.rawHandle!,
                            ptr,
                            DWORD(truncatingIfNeeded: remaining),
                            &written,
                            nil
                        )
                    )
                    guard success else {
                        throw .writeFailed(
                            errno: Int32(GetLastError()),
                            message: "WriteFile failed"
                        )
                    }
                    totalWritten += Int(written)
                }
            #elseif canImport(Darwin)
                var totalWritten = 0
                while totalWritten < count {
                    let remaining = count - totalWritten
                    let w = Darwin.write(
                        _descriptor.rawValue,
                        base.advanced(by: totalWritten),
                        remaining
                    )
                    if w > 0 {
                        totalWritten += w
                    } else if w < 0 {
                        if errno == EINTR { continue }
                        throw .writeFailed(errno: errno, message: String(cString: strerror(errno)))
                    }
                }
            #elseif canImport(Glibc)
                var totalWritten = 0
                while totalWritten < count {
                    let remaining = count - totalWritten
                    let w = Glibc.write(
                        _descriptor.rawValue,
                        base.advanced(by: totalWritten),
                        remaining
                    )
                    if w > 0 {
                        totalWritten += w
                    } else if w < 0 {
                        if errno == EINTR { continue }
                        throw .writeFailed(errno: errno, message: String(cString: strerror(errno)))
                    }
                }
            #elseif canImport(Musl)
                var totalWritten = 0
                while totalWritten < count {
                    let remaining = count - totalWritten
                    let w = Musl.write(
                        _descriptor.rawValue,
                        base.advanced(by: totalWritten),
                        remaining
                    )
                    if w > 0 {
                        totalWritten += w
                    } else if w < 0 {
                        if errno == EINTR { continue }
                        throw .writeFailed(errno: errno, message: String(cString: strerror(errno)))
                    }
                }
            #endif
        }
    }

    /// Seeks to a position in the file.
    ///
    /// - Parameters:
    ///   - offset: The offset to seek to.
    ///   - origin: The origin for the seek.
    /// - Returns: The new position in the file.
    /// - Throws: `File.Handle.Error` on failure.
    @discardableResult
    public mutating func seek(
        to offset: Int64,
        from origin: SeekOrigin = .start
    ) throws(Error) -> Int64 {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        #if os(Windows)
            var newPosition: LARGE_INTEGER = LARGE_INTEGER()
            var distance: LARGE_INTEGER = LARGE_INTEGER()
            distance.QuadPart = offset

            let whence: DWORD
            switch origin {
            case .start: whence = _dword(FILE_BEGIN)
            case .current: whence = _dword(FILE_CURRENT)
            case .end: whence = _dword(FILE_END)
            }

            guard _ok(SetFilePointerEx(_descriptor.rawHandle!, distance, &newPosition, whence))
            else {
                throw .seekFailed(errno: Int32(GetLastError()), message: "SetFilePointerEx failed")
            }
            return newPosition.QuadPart
        #else
            let whence: Int32
            switch origin {
            case .start: whence = SEEK_SET
            case .current: whence = SEEK_CUR
            case .end: whence = SEEK_END
            }

            let result = lseek(_descriptor.rawValue, off_t(offset), whence)
            guard result >= 0 else {
                throw .seekFailed(errno: errno, message: String(cString: strerror(errno)))
            }
            return Int64(result)
        #endif
    }

    /// Syncs the file to disk.
    ///
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func sync() throws(Error) {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        #if os(Windows)
            guard FlushFileBuffers(_descriptor.rawHandle!) else {
                throw .writeFailed(errno: Int32(GetLastError()), message: "FlushFileBuffers failed")
            }
        #else
            guard fsync(_descriptor.rawValue) == 0 else {
                throw .writeFailed(errno: errno, message: String(cString: strerror(errno)))
            }
        #endif
    }

    /// Closes the handle.
    ///
    /// - Postcondition: `isValid == false`
    /// - Idempotent: second close throws `.alreadyClosed`
    /// - Throws: `File.Handle.Error` on close failure
    public consuming func close() throws(Error) {
        guard _descriptor.isValid else {
            throw .alreadyClosed
        }
        do {
            try _descriptor.close()
        } catch let error {
            switch error {
            case .alreadyClosed:
                throw .alreadyClosed
            case .closeFailed(let errno, let message):
                throw .closeFailed(errno: errno, message: message)
            default:
                throw .closeFailed(errno: 0, message: "\(error)")
            }
        }
    }
}

// MARK: - Properties

extension File.Handle {
    /// Whether this handle is valid (not closed).
    public var isValid: Bool {
        _descriptor.isValid
    }
}

// MARK: - CustomStringConvertible for Error

extension File.Handle.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "File already exists: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .invalidHandle:
            return "Invalid file handle"
        case .alreadyClosed:
            return "Handle already closed"
        case .seekFailed(let errno, let message):
            return "Seek failed: \(message) (errno=\(errno))"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        case .writeFailed(let errno, let message):
            return "Write failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .openFailed(let errno, let message):
            return "Open failed: \(message) (errno=\(errno))"
        }
    }
}

// MARK: - Binary.Serializable

extension File.Handle.SeekOrigin: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .start: return 0
        case .current: return 1
        case .end: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .start
        case 1: self = .current
        case 2: self = .end
        default: return nil
        }
    }
}

extension File.Handle.SeekOrigin: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.Name.DecodeError.swift
// ============================================================

//
//  File.Name.DecodeError.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import RFC_4648

extension File.Name {
    /// Error thrown when decoding a `File.Name` to `String` fails.
    ///
    /// This error preserves the undecodable name so callers can:
    /// - Report diagnostics with raw byte information
    /// - Retry with lossy decoding if appropriate
    /// - Handle the entry using raw filesystem operations
    public struct DecodeError: Swift.Error, Sendable, Equatable {
        /// The undecodable name (raw bytes/code units preserved).
        public let name: File.Name

        /// Creates a decode error for the given undecodable name.
        public init(name: File.Name) {
            self.name = name
        }
    }
}

// MARK: - CustomStringConvertible

extension File.Name.DecodeError: CustomStringConvertible {
    public var description: String {
        "File.Name.DecodeError: \(name.debugDescription)"
    }
}

// MARK: - Debug Representation

extension File.Name.DecodeError {
    /// Debug description of the raw bytes (hex encoded).
    ///
    /// Useful for logging and diagnostics when a filename cannot be decoded.
    public var debugRawBytes: String {
        #if os(Windows)
            // Convert UInt16 code units to bytes (big-endian) for hex encoding
            var bytes: [UInt8] = []
            bytes.reserveCapacity(name._rawCodeUnits.count * 2)
            for codeUnit in name._rawCodeUnits {
                bytes.append(UInt8(codeUnit >> 8))
                bytes.append(UInt8(codeUnit & 0xFF))
            }
            return bytes.hex.encoded(uppercase: true)
        #else
            return name._rawBytes.hex.encoded(uppercase: true)
        #endif
    }
}

// ============================================================
// MARK: - File.Name.swift
// ============================================================

//
//  File.Name.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import RFC_4648

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File {
    /// A directory entry name that preserves the raw filesystem encoding.
    ///
    /// ## Strict Encoding Policy
    /// `File.Name` stores the raw bytes (POSIX) or UTF-16 code units (Windows)
    /// exactly as returned by the filesystem. This ensures:
    /// - **Referential integrity**: Names that cannot be decoded to `String` are still preserved
    /// - **Round-trip correctness**: You can always re-open a file you can iterate
    /// - **Debuggability**: Raw bytes available for diagnostics when decoding fails
    ///
    /// ## Usage
    /// ```swift
    /// for entry in try File.Directory.contents(at: path) {
    ///     if let name = String(entry.name) {
    ///         print("File: \(name)")
    ///     } else {
    ///         print("Undecodable filename: \(entry.name.debugDescription)")
    ///     }
    /// }
    /// ```
    public struct Name: Sendable, Equatable, Hashable {
        #if os(Windows)
            /// Raw UTF-16 code units from the filesystem (internal storage).
            @usableFromInline
            internal let _rawCodeUnits: [UInt16]
        #else
            /// Raw bytes from the filesystem (internal storage).
            @usableFromInline
            internal let _rawBytes: [UInt8]
        #endif

        #if os(Windows)
            /// Creates a name from raw UTF-16 code units.
            @usableFromInline
            internal init(rawCodeUnits: [UInt16]) {
                self._rawCodeUnits = rawCodeUnits
            }
        #else
            /// Creates a name from raw bytes.
            @usableFromInline
            internal init(rawBytes: [UInt8]) {
                self._rawBytes = rawBytes
            }
        #endif

        // MARK: - Semantic Predicates

        /// True if this name is "." or ".." (dot entries to skip during iteration).
        @usableFromInline
        internal var isDotOrDotDot: Bool {
            #if os(Windows)
                _rawCodeUnits == [0x002E] || _rawCodeUnits == [0x002E, 0x002E]
            #else
                _rawBytes == [0x2E] || _rawBytes == [0x2E, 0x2E]
            #endif
        }

        /// True if this name starts with '.' (hidden file convention on Unix-like systems).
        ///
        /// This is a semantic predicate - Walk uses this to filter hidden files
        /// without accessing raw storage directly.
        @inlinable
        public var isHiddenByDotPrefix: Bool {
            #if os(Windows)
                _rawCodeUnits.first == 0x002E
            #else
                _rawBytes.first == 0x2E
            #endif
        }
    }
}

// MARK: - String Conversion (Extension Inits)

extension String {
    /// Creates a string from a file name using strict UTF-8/UTF-16 decoding.
    ///
    /// Returns `nil` if the raw data contains invalid encoding.
    ///
    /// - POSIX: Returns `nil` if raw bytes are not valid UTF-8
    /// - Windows: Returns `nil` if raw code units contain invalid UTF-16 (e.g., lone surrogates)
    @inlinable
    public init?(_ fileName: File.Name) {
        #if os(Windows)
            guard let decoded = String._strictUTF16Decode(fileName._rawCodeUnits) else {
                return nil
            }
            self = decoded
        #else
            guard let decoded = String._strictUTF8Decode(fileName._rawBytes) else {
                return nil
            }
            self = decoded
        #endif
    }

    /// Creates a string from a file name using lossy decoding.
    ///
    /// Invalid sequences are replaced with the Unicode replacement character (U+FFFD).
    ///
    /// - Warning: Paths containing replacement characters cannot be used to re-open files.
    @inlinable
    public init(lossy fileName: File.Name) {
        #if os(Windows)
            self = Swift.String(decoding: fileName._rawCodeUnits, as: UTF16.self)
        #else
            self = Swift.String(decoding: fileName._rawBytes, as: UTF8.self)
        #endif
    }

    /// Creates a string from a file name using strict decoding.
    ///
    /// Throws `File.Name.DecodeError` if the raw data contains invalid encoding,
    /// allowing callers to access the raw bytes for diagnostics.
    ///
    /// - Parameter fileName: The file name to decode.
    /// - Throws: `File.Name.DecodeError` if decoding fails.
    @inlinable
    public init(validating fileName: File.Name) throws(File.Name.DecodeError) {
        guard let decoded = String(fileName) else {
            throw File.Name.DecodeError(name: fileName)
        }
        self = decoded
    }
}

// MARK: - Strict Decoding Helpers

extension String {
    #if !os(Windows)
        /// Strictly decodes UTF-8 bytes, returning `nil` on any invalid sequence.
        @usableFromInline
        internal static func _strictUTF8Decode(_ bytes: [UInt8]) -> String? {
            var utf8 = UTF8()
            var iterator = bytes.makeIterator()
            var scalars: [Unicode.Scalar] = []
            scalars.reserveCapacity(bytes.count)

            while true {
                switch utf8.decode(&iterator) {
                case .scalarValue(let scalar):
                    scalars.append(scalar)
                case .emptyInput:
                    return String(String.UnicodeScalarView(scalars))
                case .error:
                    return nil
                }
            }
        }
    #endif

    #if os(Windows)
        /// Strictly decodes UTF-16 code units, returning `nil` on any invalid sequence.
        /// Rejects lone surrogates and other malformed UTF-16.
        @usableFromInline
        internal static func _strictUTF16Decode(_ codeUnits: [UInt16]) -> String? {
            var utf16 = UTF16()
            var iterator = codeUnits.makeIterator()
            var scalars: [Unicode.Scalar] = []
            scalars.reserveCapacity(codeUnits.count)

            while true {
                switch utf16.decode(&iterator) {
                case .scalarValue(let scalar):
                    scalars.append(scalar)
                case .emptyInput:
                    return String(String.UnicodeScalarView(scalars))
                case .error:
                    return nil
                }
            }
        }
    #endif
}

// MARK: - CustomStringConvertible

extension File.Name: CustomStringConvertible {
    public var description: String {
        String(self) ?? String(lossy: self)
    }
}

// MARK: - CustomDebugStringConvertible

extension File.Name: CustomDebugStringConvertible {
    /// A debug description showing raw bytes/code units when decoding fails.
    public var debugDescription: String {
        if let str = String(self) {
            return "File.Name(\"\(str)\")"
        } else {
            #if os(Windows)
                // Convert UInt16 code units to bytes (big-endian) for hex encoding
                var bytes: [UInt8] = []
                bytes.reserveCapacity(_rawCodeUnits.count * 2)
                for codeUnit in _rawCodeUnits {
                    bytes.append(UInt8(codeUnit >> 8))
                    bytes.append(UInt8(codeUnit & 0xFF))
                }
                let hex = bytes.hex.encoded(uppercase: true)
                return "File.Name(invalidUTF16: [\(hex)])"
            #else
                let hex = _rawBytes.hex.encoded(uppercase: true)
                return "File.Name(invalidUTF8: [\(hex)])"
            #endif
        }
    }
}

// MARK: - Initialization from dirent/WIN32_FIND_DATAW

extension File.Name {
    #if !os(Windows)
        /// Creates a `File.Name` from a POSIX directory entry name (d_name).
        ///
        /// Extracts raw bytes using bounded access based on actual buffer size.
        @usableFromInline
        internal init<T>(posixDirectoryEntryName dName: T) {
            self = withUnsafePointer(to: dName) { ptr in
                let bufferSize = MemoryLayout<T>.size

                return ptr.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bytes in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < bufferSize && bytes[length] != 0 {
                        length += 1
                    }

                    // Copy raw bytes
                    let rawBytes = Array(UnsafeBufferPointer(start: bytes, count: length))
                    return File.Name(rawBytes: rawBytes)
                }
            }
        }
    #endif

    #if os(Windows)
        /// Creates a `File.Name` from a Windows directory entry name (cFileName).
        ///
        /// Extracts raw UTF-16 code units using bounded access based on actual buffer size.
        @usableFromInline
        internal init<T>(windowsDirectoryEntryName cFileName: T) {
            self = withUnsafePointer(to: cFileName) { ptr in
                let bufferSize = MemoryLayout<T>.size
                let elementCount = bufferSize / MemoryLayout<UInt16>.size

                return ptr.withMemoryRebound(to: UInt16.self, capacity: elementCount) { wchars in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < elementCount && wchars[length] != 0 {
                        length += 1
                    }

                    // Copy raw code units
                    let rawCodeUnits = Array(UnsafeBufferPointer(start: wchars, count: length))
                    return File.Name(rawCodeUnits: rawCodeUnits)
                }
            }
        }
    #endif
}

// REMOVED: == (File.Name, String) operators
// Under strict policy, undecodable names would silently return false,
// encouraging string-like usage. Use String(name) explicitly when
// comparison is needed.

// ============================================================
// MARK: - File.Path.Component.swift
// ============================================================

//
//  File.Path.Component.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import INCITS_4_1986
import SystemPackage

extension File.Path {
    /// A single component of a file path.
    ///
    /// A component represents a single directory or file name within a path.
    /// For example, in `/usr/local/bin`, the components are `usr`, `local`, and `bin`.
    public struct Component: Hashable, Sendable {
        @usableFromInline
        package var _component: FilePath.Component

        /// Creates a component from a SystemPackage FilePath.Component.
        @usableFromInline
        package init(__unchecked component: FilePath.Component) {
            self._component = component
        }

        /// Creates a validated component from a string.
        ///
        /// - Parameter string: The component string.
        /// - Throws: `File.Path.Component.Error` if the string is invalid.
        @inlinable
        public init(_ string: String) throws(Error) {
            guard !string.isEmpty else {
                throw .empty
            }
            // Check BOTH separators on all platforms
            // POSIX forbids `/` in filenames, Windows forbids both `/` and `\`
            guard !string.contains("/") && !string.contains("\\") else {
                throw .containsPathSeparator
            }
            if string.utf8.contains(where: \.ascii.isControl) {
                throw .containsControlCharacters
            }
            guard let component = FilePath.Component(string) else {
                throw .invalid
            }
            self._component = component
        }
    }
}

// MARK: - Error

extension File.Path.Component {
    /// Errors that can occur during component construction.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The component string is empty.
        case empty
        /// The component contains a path separator.
        case containsPathSeparator
        /// The component contains control characters.
        case containsControlCharacters
        /// The component is invalid.
        case invalid
    }
}

// MARK: - Properties

extension File.Path.Component {
    /// The string representation of this component.
    @inlinable
    public var string: String {
        _component.string
    }

    /// The file extension, or `nil` if there is none.
    @inlinable
    public var `extension`: String? {
        _component.extension
    }

    /// The filename without extension.
    @inlinable
    public var stem: String? {
        _component.stem
    }

    /// The underlying SystemPackage FilePath.Component.
    @inlinable
    public var filePathComponent: FilePath.Component {
        _component
    }
}

// MARK: - ExpressibleByStringLiteral

extension File.Path.Component: ExpressibleByStringLiteral {
    /// Creates a component from a string literal.
    ///
    /// String literals are compile-time constants, so validation failures
    /// are programmer errors and will trigger a fatal error.
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid component literal: \(error)")
        }
    }
}

// ============================================================
// MARK: - File.Path.Error.swift
// ============================================================

//
//  File.Path.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Path {
    /// Errors that can occur during path construction.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The path string is empty.
        case empty

        /// The path contains control characters (NUL, LF, CR, etc.).
        ///
        /// Control characters are invalid in file paths and can cause
        /// security issues or unexpected behavior with system calls.
        case containsControlCharacters
    }
}

// ============================================================
// MARK: - File.Path.swift
// ============================================================

//
//  File.Path.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import INCITS_4_1986
import SystemPackage

extension File {
    /// A file system path.
    ///
    /// `File.Path` wraps `SystemPackage.FilePath` with a consistent API
    /// that follows swift-file-system naming conventions.
    ///
    /// Path validation happens at construction time. A `File.Path` is guaranteed
    /// to be non-empty and free of control characters.
    ///
    /// ## Example
    /// ```swift
    /// let path = try File.Path.init("/usr/local/bin")
    /// let child = path / "swift"
    /// print(child.string)  // "/usr/local/bin/swift"
    /// ```
    public struct Path: Hashable, Sendable {
        @usableFromInline
        package var _path: FilePath

        /// Creates a validated path from a string.
        ///
        /// - Parameter string: The path string to validate and wrap.
        /// - Throws: `File.Path.Error` if the path is empty or contains control characters.
        @inlinable
        public init(_ string: String) throws(Error) {
            guard !string.isEmpty else {
                throw .empty
            }

            // Check for control characters before FilePath conversion
            // (FilePath may truncate at NUL, so we validate the original string)
            if string.utf8.contains(where: \.ascii.isControl) {
                throw .containsControlCharacters
            }

            self._path = FilePath(string)
        }

        /// Creates a path from a SystemPackage FilePath.
        ///
        /// - Parameter filePath: The FilePath to wrap.
        /// - Throws: `File.Path.Error.empty` if the path is empty.
        @inlinable
        public init(_ filePath: FilePath) throws(Error) {
            guard !filePath.isEmpty else {
                throw .empty
            }
            self._path = filePath
        }

        /// Package non-throwing initializer for trusted string sources.
        @usableFromInline
        package init(__unchecked: Void, _ string: String) {
            self._path = FilePath(string)
        }

        /// Package non-throwing initializer for trusted FilePath sources.
        ///
        /// Use this for FilePath values derived from valid File.Path operations
        /// where we know the result cannot be empty or contain control characters.
        @usableFromInline
        package init(__unchecked: Void, _ filePath: FilePath) {
            self._path = filePath
        }
    }
}

// MARK: - Navigation

extension File.Path {
    /// The parent directory of this path, or `nil` if this is a root path.
    @inlinable
    public var parent: File.Path? {
        let parent = _path.removingLastComponent()
        guard parent != _path else { return nil }
        return File.Path(__unchecked: (), parent)
    }
}

// MARK: - Appending (Canonical Inits)

extension File.Path {
    /// Creates a new path by appending a component to a base path.
    @inlinable
    public init(_ base: File.Path, appending component: Component) {
        var copy = base._path
        copy.append(component._component)
        self.init(__unchecked: (), copy)
    }

    /// Creates a new path by appending another path to a base path.
    @inlinable
    public init(_ base: File.Path, appending other: File.Path) {
        var copy = base._path
        for component in other._path.components {
            copy.append(component)
        }
        self.init(__unchecked: (), copy)
    }

    /// Creates a new path by appending a string component to a base path.
    @inlinable
    public init(_ base: File.Path, appending string: String) {
        var copy = base._path
        copy.append(string)
        self.init(__unchecked: (), copy)
    }
}

// MARK: - Introspection

extension File.Path {
    /// The last component of the path, or `nil` if the path is empty.
    @inlinable
    public var lastComponent: Component? {
        _path.lastComponent.map { Component(__unchecked: $0) }
    }

    /// The file extension, or `nil` if there is none.
    @inlinable
    public var `extension`: String? {
        _path.extension
    }

    /// The filename without extension.
    @inlinable
    public var stem: String? {
        _path.stem
    }

    /// Whether this is an absolute path.
    @inlinable
    public var isAbsolute: Bool {
        _path.isAbsolute
    }

    /// Whether this is a relative path.
    @inlinable
    public var isRelative: Bool {
        !_path.isAbsolute
    }

    /// Whether the path is empty.
    @inlinable
    public var isEmpty: Bool {
        _path.isEmpty
    }
}

// MARK: - Conversion

extension File.Path {
    /// The string representation of this path.
    @inlinable
    public var string: String {
        _path.string
    }

    /// The underlying SystemPackage FilePath.
    ///
    /// Use this for interoperability with SystemPackage APIs.
    @inlinable
    public var filePath: FilePath {
        _path
    }
}

// MARK: - ExpressibleByStringLiteral

extension File.Path: ExpressibleByStringLiteral {
    /// Creates a path from a string literal.
    ///
    /// String literals are compile-time constants, so validation failures
    /// are programmer errors and will trigger a fatal error.
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path literal: \(error)")
        }
    }
}

// MARK: - Operators

extension File.Path {
    /// Appends a string component to a path.
    ///
    /// ```swift
    /// let path: File.Path = "/usr/local"
    /// let bin = path / "bin"  // "/usr/local/bin"
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: String) -> File.Path {
        File.Path(lhs, appending: rhs)
    }

    /// Appends a validated component to a path.
    ///
    /// ```swift
    /// let component = try File.Path.Component("config.json")
    /// let path = basePath / component
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: Component) -> File.Path {
        File.Path(lhs, appending: rhs)
    }

    /// Appends a path to a path.
    ///
    /// ```swift
    /// let base: File.Path = "/var/log"
    /// let sub: File.Path = "app/errors"
    /// let full = base / sub  // "/var/log/app/errors"
    /// ```
    @inlinable
    public static func / (lhs: File.Path, rhs: File.Path) -> File.Path {
        File.Path(lhs, appending: rhs)
    }
}

// ============================================================
// MARK: - File.System.Copy+POSIX.swift
// ============================================================

//
//  File.System.Copy+POSIX.swift
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

    extension File.System.Copy {
        /// Copies a file using POSIX APIs with kernel-assisted fast paths.
        ///
        /// ## Fallback Ladder
        /// - **Darwin**: copyfile(CLONE_FORCE) → copyfile(ALL/DATA) → manual loop
        /// - **Linux**: sendfile → manual loop
        /// - **Other POSIX**: manual loop only
        internal static func _copyPOSIX(
            from source: File.Path,
            to destination: File.Path,
            options: Options
        ) throws(Error) {
            // Stat source (lstat when not following symlinks)
            var sourceStat = stat()
            let statResult: Int32
            if options.followSymlinks {
                statResult = stat(source.string, &sourceStat)
            } else {
                statResult = lstat(source.string, &sourceStat)
            }

            guard statResult == 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }

            // Check if source is a directory
            if (sourceStat.st_mode & S_IFMT) == S_IFDIR {
                throw .isDirectory(source)
            }

            // Check if source is a symlink and we're not following
            let sourceIsSymlink = (sourceStat.st_mode & S_IFMT) == S_IFLNK

            // Check if destination exists (use lstat to detect symlinks)
            var destStat = stat()
            let destExists = lstat(destination.string, &destStat) == 0

            if destExists {
                if !options.overwrite {
                    throw .destinationExists(destination)
                }
                // Cannot overwrite a directory
                if (destStat.st_mode & S_IFMT) == S_IFDIR {
                    throw .isDirectory(destination)
                }
                // Unlink destination before copy to replace directory entry
                // This is critical: without this, writing to a symlink writes through to target
                _ = unlink(destination.string)
            }

            // Handle symlink copying when followSymlinks=false
            if !options.followSymlinks && sourceIsSymlink {
                try _copySymlink(from: source, to: destination)
                return
            }

            // Darwin: try kernel-assisted copy first (before opening fds)
            // Note: We only use the fast path when copyAttributes is true, because
            // copyfile() always copies permissions even with COPYFILE_DATA only
            #if canImport(Darwin)
                if options.copyAttributes {
                    if _copyDarwinFast(from: source, to: destination, options: options) {
                        return
                    }
                }
            #endif

            // Open source for reading
            let srcFd = open(source.string, O_RDONLY)
            guard srcFd >= 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }
            defer { _ = close(srcFd) }

            // Create/truncate destination
            let dstFlags: Int32 = O_WRONLY | O_CREAT | O_TRUNC
            // When copyAttributes is true, preserve source permissions; otherwise use default (0o666 modified by umask)
            let dstMode: mode_t = options.copyAttributes ? (sourceStat.st_mode & 0o7777) : 0o666
            let dstFd = open(destination.string, dstFlags, dstMode)
            guard dstFd >= 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }

            var success = false
            defer {
                _ = close(dstFd)
                if !success {
                    _ = unlink(destination.string)
                }
            }

            // Linux: try kernel-assisted copy (sendfile → manual)
            #if os(Linux) && canImport(Glibc)
                if try _copyLinuxFast(
                    srcFd: srcFd,
                    dstFd: dstFd,
                    sourceSize: Int64(sourceStat.st_size)
                ) {
                    if options.copyAttributes {
                        _ = fchmod(dstFd, sourceStat.st_mode & 0o7777)
                        var times = [
                            timespec(
                                tv_sec: sourceStat.st_atim.tv_sec,
                                tv_nsec: sourceStat.st_atim.tv_nsec
                            ),
                            timespec(
                                tv_sec: sourceStat.st_mtim.tv_sec,
                                tv_nsec: sourceStat.st_mtim.tv_nsec
                            ),
                        ]
                        _ = futimens(dstFd, &times)
                    }
                    success = true
                    return
                }
            #endif

            // Fallback: manual buffer copy
            try _copyManualLoop(
                srcFd: srcFd,
                dstFd: dstFd,
                source: source,
                destination: destination
            )

            // Copy attributes if requested
            if options.copyAttributes {
                _ = fchmod(dstFd, sourceStat.st_mode & 0o7777)

                #if canImport(Darwin)
                    var times = [
                        timespec(
                            tv_sec: sourceStat.st_atimespec.tv_sec,
                            tv_nsec: sourceStat.st_atimespec.tv_nsec
                        ),
                        timespec(
                            tv_sec: sourceStat.st_mtimespec.tv_sec,
                            tv_nsec: sourceStat.st_mtimespec.tv_nsec
                        ),
                    ]
                #else
                    var times = [
                        timespec(
                            tv_sec: sourceStat.st_atim.tv_sec,
                            tv_nsec: sourceStat.st_atim.tv_nsec
                        ),
                        timespec(
                            tv_sec: sourceStat.st_mtim.tv_sec,
                            tv_nsec: sourceStat.st_mtim.tv_nsec
                        ),
                    ]
                #endif
                _ = futimens(dstFd, &times)
            }

            success = true
        }

        // MARK: - Manual Loop Fallback

        /// Copies data using a manual read/write loop (64KB buffer).
        internal static func _copyManualLoop(
            srcFd: Int32,
            dstFd: Int32,
            source: File.Path,
            destination: File.Path
        ) throws(Error) {
            let bufferSize = 64 * 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)

            while true {
                let bytesRead: Int = buffer.withUnsafeMutableBufferPointer { ptr in
                    guard let base = ptr.baseAddress else { return 0 }
                    return read(srcFd, base, bufferSize)
                }

                if bytesRead < 0 {
                    if errno == EINTR { continue }
                    throw _mapErrno(errno, source: source, destination: destination)
                }

                if bytesRead == 0 {
                    return  // EOF
                }

                var written = 0
                while written < bytesRead {
                    let w: Int = buffer.withUnsafeBufferPointer { ptr in
                        guard let base = ptr.baseAddress else { return 0 }
                        return write(dstFd, base.advanced(by: written), bytesRead - written)
                    }

                    if w < 0 {
                        if errno == EINTR { continue }
                        throw _mapErrno(errno, source: source, destination: destination)
                    }

                    written += w
                }
            }
        }

        // MARK: - Symlink Copy

        /// Copies a symlink by reading its target and creating a new symlink.
        ///
        /// This is used when `followSymlinks=false` and the source is a symlink.
        /// We replicate the link itself rather than copying the target's contents.
        private static func _copySymlink(
            from source: File.Path,
            to destination: File.Path
        ) throws(Error) {
            // Read the symlink target
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
            let len = readlink(source.string, &buffer, buffer.count - 1)
            guard len >= 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }
            // Create symlink at destination - convert CChar to UInt8 for String decoding
            let target = buffer.prefix(len).withUnsafeBufferPointer { ptr in
                String(decoding: UnsafeRawBufferPointer(ptr), as: UTF8.self)
            }
            guard symlink(target, destination.string) == 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }
        }

        // MARK: - Darwin Fast Path

        #if canImport(Darwin)
            /// Attempts kernel-assisted copy using Darwin copyfile().
            ///
            /// - Returns: `true` if copy succeeded, `false` if fallback needed.
            internal static func _copyDarwinFast(
                from source: File.Path,
                to destination: File.Path,
                options: Options
            ) -> Bool {
                var flags: copyfile_flags_t = copyfile_flags_t(
                    options.copyAttributes ? COPYFILE_ALL : COPYFILE_DATA
                )
                if !options.followSymlinks {
                    flags |= copyfile_flags_t(COPYFILE_NOFOLLOW)
                }
                if options.overwrite {
                    flags |= copyfile_flags_t(COPYFILE_UNLINK)
                }

                // Try clone first (APFS instant copy) - but only when copying attributes,
                // because clone always preserves metadata regardless of COPYFILE_DATA flag
                if options.copyAttributes {
                    if copyfile(
                        source.string,
                        destination.string,
                        nil,
                        flags | copyfile_flags_t(COPYFILE_CLONE_FORCE)
                    ) == 0 {
                        return true
                    }
                }

                // Fall back to full kernel copy (COPYFILE_DATA or COPYFILE_ALL)
                if copyfile(source.string, destination.string, nil, flags) == 0 {
                    return true
                }

                return false
            }
        #endif

        // MARK: - Linux Fast Path

        #if os(Linux) && canImport(Glibc)
            /// Attempts kernel-assisted copy using Linux sendfile.
            ///
            /// Uses sendfile for kernel-assisted copy. Falls back to manual loop
            /// if sendfile is unavailable or fails.
            ///
            /// Note: copy_file_range would be faster for same-filesystem copies
            /// but requires a C shim to access reliably. Planned for future release.
            ///
            /// - Returns: `true` if copy succeeded, `false` if fallback needed.
            internal static func _copyLinuxFast(
                srcFd: Int32,
                dstFd: Int32,
                sourceSize: Int64
            ) throws(Error) -> Bool {
                var remaining = sourceSize

                while remaining > 0 {
                    let chunk = remaining > Int64(Int.max) ? Int.max : Int(remaining)
                    let sent = sendfile(dstFd, srcFd, nil, chunk)
                    if sent < 0 {
                        if errno == ENOSYS || errno == EINVAL {
                            return false  // Fall back to manual loop
                        }
                        throw .copyFailed(errno: errno, message: String(cString: strerror(errno)))
                    }
                    if sent == 0 {
                        break
                    }
                    remaining -= Int64(sent)
                }

                return remaining == 0
            }
        #endif

        // MARK: - Error Mapping

        /// Maps errno to copy error.
        private static func _mapErrno(
            _ errno: Int32,
            source: File.Path,
            destination: File.Path
        ) -> Error {
            switch errno {
            case ENOENT:
                return .sourceNotFound(source)
            case EEXIST:
                return .destinationExists(destination)
            case EACCES, EPERM:
                return .permissionDenied(source)
            case EISDIR:
                return .isDirectory(source)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .copyFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Copy+Windows.swift
// ============================================================

//
//  File.System.Copy+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    import WinSDK

    extension File.System.Copy {
        /// Copies a file using Windows APIs.
        internal static func _copyWindows(
            from source: File.Path,
            to destination: File.Path,
            options: Options
        ) throws(Error) {
            // Check if source exists and is not a directory
            let srcAttrs = source.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard srcAttrs != INVALID_FILE_ATTRIBUTES else {
                throw .sourceNotFound(source)
            }

            if (srcAttrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                throw .isDirectory(source)
            }

            // Check destination
            let dstAttrs = destination.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            if dstAttrs != INVALID_FILE_ATTRIBUTES && !options.overwrite {
                throw .destinationExists(destination)
            }

            // Use CopyFileW for simple copy
            // failIfExists: true means fail if destination exists
            let failIfExists: Bool = !options.overwrite

            let success = source.string.withCString(encodedAs: UTF16.self) { wsrc in
                destination.string.withCString(encodedAs: UTF16.self) { wdst in
                    CopyFileW(wsrc, wdst, failIfExists)
                }
            }

            guard success else {
                throw _mapWindowsError(GetLastError(), source: source, destination: destination)
            }
        }

        /// Maps Windows error to copy error.
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
                return .copyFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Copy.swift
// ============================================================

//
//  File.System.Copy.swift
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

extension File.System {
    /// Namespace for file copy operations.
    public enum Copy {}
}

// MARK: - Options

extension File.System.Copy {
    /// Options for copy operations.
    public struct Options: Sendable {
        /// Overwrite existing destination.
        public var overwrite: Bool

        /// Copy extended attributes.
        public var copyAttributes: Bool

        /// Follow symbolic links (copy target instead of link).
        public var followSymlinks: Bool

        public init(
            overwrite: Bool = false,
            copyAttributes: Bool = true,
            followSymlinks: Bool = true
        ) {
            self.overwrite = overwrite
            self.copyAttributes = copyAttributes
            self.followSymlinks = followSymlinks
        }
    }
}

// MARK: - Error

extension File.System.Copy {
    /// Errors that can occur during copy operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case destinationExists(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case copyFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Copy {
    /// Copies a file from source to destination with options.
    ///
    /// - Parameters:
    ///   - source: The source file path.
    ///   - destination: The destination file path.
    ///   - options: Copy options.
    /// - Throws: `File.System.Copy.Error` on failure.
    public static func copy(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init()
    ) throws(Error) {
        #if os(Windows)
            try _copyWindows(from: source, to: destination, options: options)
        #else
            try _copyPOSIX(from: source, to: destination, options: options)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Copy.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .sourceNotFound(let path):
            return "Source not found: \(path)"
        case .destinationExists(let path):
            return "Destination already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .copyFailed(let errno, let message):
            return "Copy failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Create.Directory+POSIX.swift
// ============================================================

//
//  File.System.Create.Directory+POSIX.swift
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

    extension File.System.Create.Directory {
        /// Creates a directory using POSIX APIs.
        internal static func _createPOSIX(at path: File.Path, options: Options) throws(Error) {
            let mode =
                options.permissions?.rawValue
                ?? File.System.Metadata.Permissions.defaultDirectory.rawValue

            if options.createIntermediates {
                try _createIntermediates(at: path, mode: mode_t(mode))
            } else {
                guard mkdir(path.string, mode_t(mode)) == 0 else {
                    throw _mapErrno(errno, path: path)
                }
            }
        }

        /// Creates a directory and all intermediate directories.
        private static func _createIntermediates(at path: File.Path, mode: mode_t) throws(Error) {
            // Check if directory already exists
            var statBuf = stat()
            if stat(path.string, &statBuf) == 0 {
                if (statBuf.st_mode & S_IFMT) == S_IFDIR {
                    // Already exists as directory - success
                    return
                } else {
                    throw .alreadyExists(path)
                }
            }

            // Try to create parent directory first
            let pathString = path.string
            if let lastSlash = pathString.lastIndex(of: "/"), lastSlash != pathString.startIndex {
                let parentString = String(pathString[..<lastSlash])
                if !parentString.isEmpty {
                    if let parentPath = try? File.Path(parentString) {
                        try _createIntermediates(at: parentPath, mode: mode)
                    }
                }
            }

            // Now create this directory
            if mkdir(path.string, mode) != 0 {
                let error = errno
                // Check if it was created by another process/thread in the meantime
                if error == EEXIST {
                    if stat(path.string, &statBuf) == 0 && (statBuf.st_mode & S_IFMT) == S_IFDIR {
                        return
                    }
                }
                throw _mapErrno(error, path: path)
            }
        }

        /// Maps errno to create error.
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case EEXIST:
                return .alreadyExists(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOENT:
                return .parentDirectoryNotFound(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .createFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Create.Directory+Windows.swift
// ============================================================

//
//  File.System.Create.Directory+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    import WinSDK

    extension File.System.Create.Directory {
        /// Creates a directory using Windows APIs.
        internal static func _createWindows(at path: File.Path, options: Options) throws(Error) {
            if options.createIntermediates {
                try _createIntermediates(at: path)
            } else {
                let success = path.string.withCString(encodedAs: UTF16.self) { wpath in
                    CreateDirectoryW(wpath, nil)
                }
                guard _ok(success) else {
                    throw _mapWindowsError(GetLastError(), path: path)
                }
            }
        }

        /// Creates a directory and all intermediate directories.
        private static func _createIntermediates(at path: File.Path) throws(Error) {
            // Check if directory already exists
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            if attrs != INVALID_FILE_ATTRIBUTES {
                if (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    // Already exists as directory - success
                    return
                } else {
                    throw .alreadyExists(path)
                }
            }

            // Try to create parent directory first
            let pathString = path.string
            if let lastSlash = pathString.lastIndex(where: { $0 == "/" || $0 == "\\" }),
                lastSlash != pathString.startIndex
            {
                let parentString = String(pathString[..<lastSlash])
                if !parentString.isEmpty && !parentString.hasSuffix(":") {
                    if let parentPath = try? File.Path(parentString) {
                        try _createIntermediates(at: parentPath)
                    }
                }
            }

            // Now create this directory
            let success = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateDirectoryW(wpath, nil)
            }

            if !_ok(success) {
                let error = GetLastError()
                // Check if it was created by another process/thread in the meantime
                if error == _dword(ERROR_ALREADY_EXISTS) {
                    let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                        GetFileAttributesW(wpath)
                    }
                    if attrs != INVALID_FILE_ATTRIBUTES
                        && (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0
                    {
                        return
                    }
                }
                throw _mapWindowsError(error, path: path)
            }
        }

        /// Maps Windows error to create error.
        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_ALREADY_EXISTS), _dword(ERROR_FILE_EXISTS):
                return .alreadyExists(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_PATH_NOT_FOUND):
                return .parentDirectoryNotFound(path)
            default:
                return .createFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Create.Directory.swift
// ============================================================

//
//  File.System.Create.Directory.swift
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

extension File.System.Create {
    /// Create new directories.
    public enum Directory {}
}

// MARK: - Options

extension File.System.Create.Directory {
    /// Options for directory creation.
    public struct Options: Sendable {
        /// Create intermediate directories as needed.
        public var createIntermediates: Bool

        /// Permissions for the new directory.
        public var permissions: File.System.Metadata.Permissions?

        public init(
            createIntermediates: Bool = false,
            permissions: File.System.Metadata.Permissions? = nil
        ) {
            self.createIntermediates = createIntermediates
            self.permissions = permissions
        }
    }
}

// MARK: - Error

extension File.System.Create.Directory {
    /// Errors that can occur during directory creation operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case alreadyExists(File.Path)
        case permissionDenied(File.Path)
        case parentDirectoryNotFound(File.Path)
        case createFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Create.Directory {
    /// Creates a directory at the specified path.
    ///
    /// - Parameter path: The path where the directory should be created.
    /// - Throws: `File.System.Create.Directory.Error` on failure.
    public static func create(at path: File.Path) throws(Error) {
        #if os(Windows)
            try _createWindows(at: path, options: Options())
        #else
            try _createPOSIX(at: path, options: Options())
        #endif
    }

    /// Creates a directory at the specified path with options.
    ///
    /// - Parameters:
    ///   - path: The path where the directory should be created.
    ///   - options: Creation options (e.g., create intermediates).
    /// - Throws: `File.System.Create.Directory.Error` on failure.
    public static func create(at path: File.Path, options: Options) throws(Error) {
        #if os(Windows)
            try _createWindows(at: path, options: options)
        #else
            try _createPOSIX(at: path, options: options)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Create.Directory.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .alreadyExists(let path):
            return "Directory already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .parentDirectoryNotFound(let path):
            return "Parent directory not found: \(path)"
        case .createFailed(let errno, let message):
            return "Create failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Create.File.swift
// ============================================================

//
//  File.System.Create.File.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Create {
    /// Create new files.
    public enum File {
        // TODO: Implementation
    }
}

extension File.System.Create.File {
    /// Error type for file creation operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case alreadyExists(File_System_Primitives.File.Path)
        case permissionDenied(File_System_Primitives.File.Path)
        case parentDirectoryNotFound(File_System_Primitives.File.Path)
        case createFailed(errno: Int32, message: String)
    }
}

// ============================================================
// MARK: - File.System.Create.swift
// ============================================================

//
//  File.System.Create.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file and directory creation operations.
    public enum Create {}
}

extension File.System.Create {
    /// General options for creation operations.
    public struct Options: Sendable {
        /// File permissions for the created item.
        public var permissions: File_System_Primitives.File.System.Metadata.Permissions?

        public init(permissions: File_System_Primitives.File.System.Metadata.Permissions? = nil) {
            self.permissions = permissions
        }
    }
}

// ============================================================
// MARK: - File.System.Delete+POSIX.swift
// ============================================================

//
//  File.System.Delete+POSIX.swift
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

    extension File.System.Delete {
        /// Deletes a file or directory using POSIX APIs.
        internal static func _deletePOSIX(at path: File.Path, options: Options) throws(Error) {
            // First, stat the path to determine what it is
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            let isDir = (statBuf.st_mode & S_IFMT) == S_IFDIR

            if isDir {
                if options.recursive {
                    try _deleteDirectoryRecursive(at: path)
                } else {
                    // Try to remove empty directory
                    guard rmdir(path.string) == 0 else {
                        throw _mapErrno(errno, path: path)
                    }
                }
            } else {
                // Remove file
                guard unlink(path.string) == 0 else {
                    throw _mapErrno(errno, path: path)
                }
            }
        }

        /// Recursively deletes a directory and all its contents.
        private static func _deleteDirectoryRecursive(at path: File.Path) throws(Error) {
            // Open directory
            guard let dir = opendir(path.string) else {
                throw _mapErrno(errno, path: path)
            }
            defer { closedir(dir) }

            // Iterate through entries
            while let entry = readdir(dir) {
                let fileName = File.Name(posixDirectoryEntryName: entry.pointee.d_name)

                // Skip . and .. using raw byte comparison (no decoding)
                if fileName.isDotOrDotDot {
                    continue
                }

                // For delete, we need a valid string path
                // If name can't be decoded, skip (can't safely delete what we can't name)
                guard let name = String(fileName) else {
                    continue
                }

                // Construct full path using proper path composition
                let childPath = File.Path(path, appending: name)

                // Stat to determine type
                var childStat = stat()
                guard stat(childPath.string, &childStat) == 0 else {
                    throw _mapErrno(errno, path: childPath)
                }

                if (childStat.st_mode & S_IFMT) == S_IFDIR {
                    // Recursively delete subdirectory
                    try _deleteDirectoryRecursive(at: childPath)
                } else {
                    // Delete file
                    guard unlink(childPath.string) == 0 else {
                        throw _mapErrno(errno, path: childPath)
                    }
                }
            }

            // Now delete the empty directory
            guard rmdir(path.string) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        }

        /// Maps errno to delete error.
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EISDIR:
                return .isDirectory(path)
            case ENOTEMPTY:
                return .directoryNotEmpty(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .deleteFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Delete+Windows.swift
// ============================================================

//
//  File.System.Delete+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    import WinSDK

    extension File.System.Delete {
        /// Deletes a file or directory using Windows APIs.
        internal static func _deleteWindows(at path: File.Path, options: Options) throws(Error) {
            // Get file attributes to determine type
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            let isDir = (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0

            if isDir {
                if options.recursive {
                    try _deleteDirectoryRecursive(at: path)
                } else {
                    // Try to remove empty directory
                    let success = path.string.withCString(encodedAs: UTF16.self) { wpath in
                        RemoveDirectoryW(wpath)
                    }
                    guard _ok(success) else {
                        throw _mapWindowsError(GetLastError(), path: path)
                    }
                }
            } else {
                // Remove file
                let success = path.string.withCString(encodedAs: UTF16.self) { wpath in
                    DeleteFileW(wpath)
                }
                guard _ok(success) else {
                    throw _mapWindowsError(GetLastError(), path: path)
                }
            }
        }

        /// Recursively deletes a directory and all its contents.
        private static func _deleteDirectoryRecursive(at path: File.Path) throws(Error) {
            var findData = WIN32_FIND_DATAW()
            let searchPath = path.string + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            defer { FindClose(handle) }

            repeat {
                let fileName = File.Name(windowsDirectoryEntryName: findData.cFileName)

                // Skip . and .. using raw byte comparison (no decoding)
                if fileName.isDotOrDotDot {
                    continue
                }

                // For delete, we need a valid string path
                // If name can't be decoded, skip (can't safely delete what we can't name)
                guard let name = String(fileName) else {
                    continue
                }

                // Construct full path using proper path composition
                let childPath = File.Path(path, appending: name)

                let isChildDir = (findData.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0

                if isChildDir {
                    // Recursively delete subdirectory
                    try _deleteDirectoryRecursive(at: childPath)
                } else {
                    // Delete file
                    let success = childPath.string.withCString(encodedAs: UTF16.self) { wpath in
                        DeleteFileW(wpath)
                    }
                    guard _ok(success) else {
                        throw _mapWindowsError(GetLastError(), path: childPath)
                    }
                }
            } while _ok(FindNextFileW(handle, &findData))

            // Check if we stopped due to error or end of directory
            let lastError = GetLastError()
            if lastError != _dword(ERROR_NO_MORE_FILES) {
                throw _mapWindowsError(lastError, path: path)
            }

            // Now delete the empty directory
            let success = path.string.withCString(encodedAs: UTF16.self) { wpath in
                RemoveDirectoryW(wpath)
            }
            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
        }

        /// Maps Windows error to delete error.
        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_DIR_NOT_EMPTY):
                return .directoryNotEmpty(path)
            default:
                return .deleteFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Delete.swift
// ============================================================

//
//  File.System.Delete.swift
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

extension File.System {
    /// Namespace for file deletion operations.
    public enum Delete {}
}

// MARK: - Options

extension File.System.Delete {
    /// Options for delete operations.
    public struct Options: Sendable {
        /// Delete directories recursively.
        public var recursive: Bool

        public init(recursive: Bool = false) {
            self.recursive = recursive
        }
    }
}

// MARK: - Error

extension File.System.Delete {
    /// Errors that can occur during delete operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case directoryNotEmpty(File.Path)
        case deleteFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Delete {
    /// Deletes a file or directory at the specified path with options.
    ///
    /// - Parameters:
    ///   - path: The path to delete.
    ///   - options: Delete options (e.g., recursive).
    /// - Throws: `File.System.Delete.Error` on failure.
    public static func delete(at path: File.Path, options: Options = .init()) throws(Error) {
        #if os(Windows)
            try _deleteWindows(at: path, options: options)
        #else
            try _deletePOSIX(at: path, options: options)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Delete.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .isDirectory(let path):
            return "Is a directory (use recursive option): \(path)"
        case .directoryNotEmpty(let path):
            return "Directory not empty (use recursive option): \(path)"
        case .deleteFailed(let errno, let message):
            return "Delete failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Error.Code.swift
// ============================================================

//
//  File.System.Error.Code.swift
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
    import WinSDK
#endif

extension File.System.Error {
    /// Platform-specific system error code.
    ///
    /// Separates POSIX errno values from Windows error codes for proper diagnostics.
    /// Use `.posix(_)` for Unix-like systems (Darwin, Linux, etc.) and `.windows(_)`
    /// for Windows API errors.
    ///
    /// ## Example
    /// ```swift
    /// case .posix(let errno):
    ///     print("POSIX error: \(errno)")
    /// case .windows(let code):
    ///     print("Windows error: \(code)")
    /// ```
    public enum Code: Equatable, Sendable {
        /// POSIX errno value (Unix-like systems).
        case posix(Int32)

        /// Windows API error code (from GetLastError()).
        case windows(UInt32)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Error.Code: CustomStringConvertible {
    public var description: String {
        switch self {
        case .posix(let errno):
            #if !os(Windows)
            if let msg = strerror(errno) {
                return "errno \(errno): \(String(cString: msg))"
            }
            #endif
            return "errno \(errno)"

        case .windows(let code):
            return "Windows error \(code)"
        }
    }
}

// MARK: - Convenience Initializers

extension File.System.Error.Code {
    /// Creates an error code from the current platform's last error.
    ///
    /// On POSIX systems, reads `errno`. On Windows, calls `GetLastError()`.
    @inline(__always)
    public static func current() -> Self {
        #if os(Windows)
        return .windows(GetLastError())
        #else
        return .posix(errno)
        #endif
    }

    /// The raw numeric value for display purposes.
    public var rawValue: Int64 {
        switch self {
        case .posix(let errno): return Int64(errno)
        case .windows(let code): return Int64(code)
        }
    }
}

// MARK: - Error Message Helper

extension File.System.Error.Code {
    /// Returns a human-readable message for this error code.
    public var message: String {
        switch self {
        case .posix(let errno):
            #if !os(Windows)
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            #endif
            return "error \(errno)"

        case .windows(let code):
            return "Windows error \(code)"
        }
    }
}


// ============================================================
// MARK: - File.System.Link.Hard.swift
// ============================================================

//
//  File.System.Link.Hard.swift
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

extension File.System.Link {
    /// Hard link operations.
    public enum Hard {}
}

// MARK: - Error

extension File.System.Link.Hard {
    /// Errors that can occur during hard link operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case crossDevice(source: File.Path, destination: File.Path)
        case isDirectory(File.Path)
        case linkFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Link.Hard {
    /// Creates a hard link at the specified path to an existing file.
    ///
    /// - Parameters:
    ///   - path: The path where the hard link will be created.
    ///   - existing: The path to the existing file.
    /// - Throws: `File.System.Link.Hard.Error` on failure.
    public static func create(at path: File.Path, to existing: File.Path) throws(Error) {
        #if os(Windows)
            try _createWindows(at: path, to: existing)
        #else
            try _createPOSIX(at: path, to: existing)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Link.Hard {
        internal static func _createPOSIX(at path: File.Path, to existing: File.Path) throws(Error)
        {
            guard link(existing.string, path.string) == 0 else {
                throw _mapErrno(errno, path: path, existing: existing)
            }
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path, existing: File.Path) -> Error
        {
            switch errno {
            case ENOENT:
                return .sourceNotFound(existing)
            case EEXIST:
                return .alreadyExists(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EXDEV:
                return .crossDevice(source: existing, destination: path)
            case EISDIR:
                return .isDirectory(existing)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .linkFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.System.Link.Hard {
        internal static func _createWindows(
            at path: File.Path,
            to existing: File.Path
        ) throws(Error) {
            let success = existing.string.withCString(encodedAs: UTF16.self) { wexisting in
                path.string.withCString(encodedAs: UTF16.self) { wpath in
                    CreateHardLinkW(wpath, wexisting, nil)
                }
            }

            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), path: path, existing: existing)
            }
        }

        private static func _mapWindowsError(
            _ error: DWORD,
            path: File.Path,
            existing: File.Path
        ) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .sourceNotFound(existing)
            case _dword(ERROR_ALREADY_EXISTS), _dword(ERROR_FILE_EXISTS):
                return .alreadyExists(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_NOT_SAME_DEVICE):
                return .crossDevice(source: existing, destination: path)
            default:
                return .linkFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Hard.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .sourceNotFound(let path):
            return "Source not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "Link already exists: \(path)"
        case .crossDevice(let source, let destination):
            return "Cross-device link not allowed: \(source) → \(destination)"
        case .isDirectory(let path):
            return "Cannot create hard link to directory: \(path)"
        case .linkFailed(let errno, let message):
            return "Hard link creation failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Link.ReadTarget.swift
// ============================================================

//
//  File.System.Link.ReadTarget.swift
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

extension File.System.Link {
    /// Read symbolic link target.
    public enum ReadTarget {}
}

// MARK: - Error

extension File.System.Link.ReadTarget {
    /// Errors that can occur during reading link target operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case notASymlink(File.Path)
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case readFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Link.ReadTarget {
    /// Reads the target of a symbolic link.
    ///
    /// - Parameter path: The path to the symbolic link.
    /// - Returns: The target path that the symlink points to.
    /// - Throws: `File.System.Link.ReadTarget.Error` on failure.
    public static func target(of path: File.Path) throws(Error) -> File.Path {
        #if os(Windows)
            return try _targetWindows(of: path)
        #else
            return try _targetPOSIX(of: path)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Link.ReadTarget {
        internal static func _targetPOSIX(of path: File.Path) throws(Error) -> File.Path {
            // First check if it's a symlink
            var statBuf = stat()
            guard lstat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            guard (statBuf.st_mode & S_IFMT) == S_IFLNK else {
                throw .notASymlink(path)
            }

            // Read the link target
            var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
            let length = readlink(path.string, &buffer, Int(PATH_MAX))

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
    extension File.System.Link.ReadTarget {
        internal static func _targetWindows(of path: File.Path) throws(Error) -> File.Path {
            // Check if it's a reparse point (symlink)
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                throw .pathNotFound(path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 else {
                throw .notASymlink(path)
            }

            // Open the file to read the reparse point
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _dword(GENERIC_READ),
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

            // Get the final path name
            var buffer = [UInt16](repeating: 0, count: Int(MAX_PATH) + 1)
            let length = buffer.withUnsafeMutableBufferPointer { ptr -> DWORD in
                guard let base = ptr.baseAddress else { return 0 }
                return GetFinalPathNameByHandleW(
                    handle,
                    base,
                    _dword(MAX_PATH),
                    _dword(FILE_NAME_NORMALIZED)
                )
            }

            guard length > 0 && length < MAX_PATH else {
                throw .readFailed(
                    errno: Int32(GetLastError()),
                    message: "GetFinalPathNameByHandleW failed"
                )
            }

            var targetString = String(decodingCString: buffer, as: UTF16.self)

            // Remove \\?\ prefix if present
            if targetString.hasPrefix("\\\\?\\") {
                targetString = String(targetString.dropFirst(4))
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

extension File.System.Link.ReadTarget.Error: CustomStringConvertible {
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

// ============================================================
// MARK: - File.System.Link.Symbolic.swift
// ============================================================

//
//  File.System.Link.Symbolic.swift
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

extension File.System.Link {
    /// Symbolic link operations.
    public enum Symbolic {}
}

// MARK: - Error

extension File.System.Link.Symbolic {
    /// Errors that can occur during symbolic link operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case targetNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case linkFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Link.Symbolic {
    /// Creates a symbolic link at the specified path pointing to target.
    ///
    /// - Parameters:
    ///   - path: The path where the symlink will be created.
    ///   - target: The path the symlink will point to.
    /// - Throws: `File.System.Link.Symbolic.Error` on failure.
    public static func create(at path: File.Path, pointingTo target: File.Path) throws(Error) {
        #if os(Windows)
            try _createWindows(at: path, pointingTo: target)
        #else
            try _createPOSIX(at: path, pointingTo: target)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Link.Symbolic {
        internal static func _createPOSIX(
            at path: File.Path,
            pointingTo target: File.Path
        ) throws(Error) {
            guard symlink(target.string, path.string) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case EEXIST:
                return .alreadyExists(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case ENOENT:
                return .targetNotFound(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .linkFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.System.Link.Symbolic {
        internal static func _createWindows(
            at path: File.Path,
            pointingTo target: File.Path
        ) throws(Error) {
            // Check if target is a directory
            let targetAttrs = target.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            var flags: DWORD = _dword(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
            if targetAttrs != INVALID_FILE_ATTRIBUTES
                && (targetAttrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0
            {
                flags |= _dword(SYMBOLIC_LINK_FLAG_DIRECTORY)
            }

            let success = path.string.withCString(encodedAs: UTF16.self) { wlink in
                target.string.withCString(encodedAs: UTF16.self) { wtarget in
                    CreateSymbolicLinkW(wlink, wtarget, flags)
                }
            }

            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
        }

        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_ALREADY_EXISTS), _dword(ERROR_FILE_EXISTS):
                return .alreadyExists(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_PATH_NOT_FOUND):
                return .targetNotFound(path)
            default:
                return .linkFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.System.Link.Symbolic.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .targetNotFound(let path):
            return "Target not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "Link already exists: \(path)"
        case .linkFailed(let errno, let message):
            return "Symlink creation failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Link.swift
// ============================================================

//
//  File.System.Link.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for symbolic and hard link operations.
    public enum Link {}
}

// ============================================================
// MARK: - File.System.Metadata.ACL.swift
// ============================================================

//
//  File.System.Metadata.ACL.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// Access Control Lists.
    public enum ACL {
        // TODO: Implementation
    }
}

// ============================================================
// MARK: - File.System.Metadata.Attributes.swift
// ============================================================

//
//  File.System.Metadata.Attributes.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// Extended file attributes (xattrs).
    public enum Attributes {
        // TODO: Implementation
    }
}

extension File.System.Metadata.Attributes {
    /// Error type for extended attribute operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case attributeNotFound(name: String, path: File.Path)
        case notSupported(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// ============================================================
// MARK: - File.System.Metadata.Info.swift
// ============================================================

//
//  File.System.Metadata.Info.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// File metadata information (stat result).
    public struct Info: Sendable {
        /// File size in bytes.
        public let size: Int64

        /// File permissions.
        public let permissions: Permissions

        /// File ownership.
        public let owner: Ownership

        /// File timestamps.
        public let timestamps: Timestamps

        /// File type.
        public let type: Kind

        /// Inode number.
        public let inode: UInt64

        /// Device ID.
        public let deviceId: UInt64

        /// Number of hard links.
        public let linkCount: UInt32

        public init(
            size: Int64,
            permissions: Permissions,
            owner: Ownership,
            timestamps: Timestamps,
            type: Kind,
            inode: UInt64,
            deviceId: UInt64,
            linkCount: UInt32
        ) {
            self.size = size
            self.permissions = permissions
            self.owner = owner
            self.timestamps = timestamps
            self.type = type
            self.inode = inode
            self.deviceId = deviceId
            self.linkCount = linkCount
        }
    }
}

// ============================================================
// MARK: - File.System.Metadata.Ownership.swift
// ============================================================

//
//  File.System.Metadata.Ownership.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Metadata {
    /// File ownership information.
    public struct Ownership: Sendable, Equatable {
        /// User ID of the owner.
        public var uid: UInt32

        /// Group ID of the owner.
        public var gid: UInt32

        public init(uid: UInt32, gid: UInt32) {
            self.uid = uid
            self.gid = gid
        }
    }
}

// MARK: - Error

extension File.System.Metadata.Ownership {
    /// Errors that can occur during ownership operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Ownership {
    /// Creates ownership by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Ownership.Error` on failure.
    public init(at path: File.Path) throws(Error) {
        #if os(Windows)
            // Windows doesn't expose uid/gid
            self.init(uid: 0, gid: 0)
        #else
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: path)
            }
            self.init(uid: statBuf.st_uid, gid: statBuf.st_gid)
        #endif
    }
}

// MARK: - Set API

extension File.System.Metadata.Ownership {
    /// Sets the ownership of a file.
    ///
    /// Requires appropriate privileges (usually root).
    ///
    /// - Parameters:
    ///   - ownership: The ownership to set.
    ///   - path: The path to the file.
    /// - Throws: `File.System.Metadata.Ownership.Error` on failure.
    public static func set(_ ownership: Self, at path: File.Path) throws(Error) {
        #if os(Windows)
            // Windows doesn't support chown - this is a no-op
            return
        #else
            guard chown(path.string, ownership.uid, ownership.gid) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        #endif
    }

    #if !os(Windows)
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .operationFailed(errno: errno, message: message)
            }
        }
    #endif
}

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Ownership.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let errno, let message):
            return "Operation failed: \(message) (errno=\(errno))"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Ownership: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.uid.bytes())
        buffer.append(contentsOf: value.gid.bytes())
    }
}

// ============================================================
// MARK: - File.System.Metadata.Permissions.swift
// ============================================================

//
//  File.System.Metadata.Permissions.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Metadata {
    /// POSIX file permissions.
    public struct Permissions: OptionSet, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        // Owner permissions
        public static let ownerRead = Permissions(rawValue: 0o400)
        public static let ownerWrite = Permissions(rawValue: 0o200)
        public static let ownerExecute = Permissions(rawValue: 0o100)

        // Group permissions
        public static let groupRead = Permissions(rawValue: 0o040)
        public static let groupWrite = Permissions(rawValue: 0o020)
        public static let groupExecute = Permissions(rawValue: 0o010)

        // Other permissions
        public static let otherRead = Permissions(rawValue: 0o004)
        public static let otherWrite = Permissions(rawValue: 0o002)
        public static let otherExecute = Permissions(rawValue: 0o001)

        // Special bits
        public static let setuid = Permissions(rawValue: 0o4000)
        public static let setgid = Permissions(rawValue: 0o2000)
        public static let sticky = Permissions(rawValue: 0o1000)

        // Common combinations
        public static let ownerAll: Permissions = [.ownerRead, .ownerWrite, .ownerExecute]
        public static let groupAll: Permissions = [.groupRead, .groupWrite, .groupExecute]
        public static let otherAll: Permissions = [.otherRead, .otherWrite, .otherExecute]

        /// Default file permissions (644).
        public static let defaultFile: Permissions = [
            .ownerRead, .ownerWrite, .groupRead, .otherRead,
        ]

        /// Default directory permissions (755).
        public static let defaultDirectory: Permissions = [
            .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
        ]

        /// Executable file permissions (755).
        public static let executable: Permissions = [
            .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
        ]
    }
}

// MARK: - Error

extension File.System.Metadata.Permissions {
    /// Errors that can occur during permission operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Permissions {
    /// Creates permissions by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Permissions.Error` on failure.
    public init(at path: File.Path) throws(Error) {
        #if os(Windows)
            // Windows doesn't have POSIX permissions
            self = .defaultFile
        #else
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: path)
            }
            self.init(rawValue: UInt16(statBuf.st_mode & 0o7777))
        #endif
    }
}

// MARK: - Set API

extension File.System.Metadata.Permissions {
    /// Sets the permissions of a file.
    ///
    /// - Parameters:
    ///   - permissions: The permissions to set.
    ///   - path: The path to the file.
    /// - Throws: `File.System.Metadata.Permissions.Error` on failure.
    public static func set(_ permissions: Self, at path: File.Path) throws(Error) {
        #if os(Windows)
            // Windows doesn't have POSIX permissions - this is a no-op
            return
        #else
            guard chmod(path.string, mode_t(permissions.rawValue)) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        #endif
    }

    #if !os(Windows)
        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .operationFailed(errno: errno, message: message)
            }
        }
    #endif
}

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Permissions.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let errno, let message):
            return "Operation failed: \(message) (errno=\(errno))"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Permissions: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}

// ============================================================
// MARK: - File.System.Metadata.Timestamps.swift
// ============================================================

//
//  File.System.Metadata.Timestamps.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

@_spi(Internal) import StandardTime

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Metadata {
    /// File timestamp information.
    ///
    /// Contains access, modification, change, and optionally creation times
    /// using `Time` from StandardTime for type-safe calendar representation.
    public struct Timestamps: Sendable, Equatable {
        /// Last access time.
        public var accessTime: Time

        /// Last modification time.
        public var modificationTime: Time

        /// Status change time (ctime on POSIX, same as modification on Windows).
        public var changeTime: Time

        /// Creation time (birthtime), if available.
        ///
        /// Available on macOS and Windows. Returns `nil` on Linux.
        public var creationTime: Time?

        public init(
            accessTime: Time,
            modificationTime: Time,
            changeTime: Time,
            creationTime: Time? = nil
        ) {
            self.accessTime = accessTime
            self.modificationTime = modificationTime
            self.changeTime = changeTime
            self.creationTime = creationTime
        }
    }
}

// MARK: - Error

extension File.System.Metadata.Timestamps {
    /// Errors that can occur during timestamp operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case operationFailed(errno: Int32, message: String)
    }
}

// MARK: - Init from Path

extension File.System.Metadata.Timestamps {
    /// Creates timestamps by reading from a file path.
    ///
    /// - Parameter path: The path to the file.
    /// - Throws: `File.System.Metadata.Timestamps.Error` on failure.
    public init(at path: File.Path) throws(Error) {
        #if os(Windows)
            self = try Self._getWindows(path)
        #else
            self = try Self._getPOSIX(path)
        #endif
    }
}

// MARK: - Set API

extension File.System.Metadata.Timestamps {
    /// Sets the timestamps of a file.
    ///
    /// Only access and modification times can be set. Change time is
    /// automatically updated by the system.
    ///
    /// - Parameters:
    ///   - timestamps: The timestamps to set.
    ///   - path: The path to the file.
    /// - Throws: `File.System.Metadata.Timestamps.Error` on failure.
    public static func set(_ timestamps: Self, at path: File.Path) throws(Error) {
        #if os(Windows)
            try _setWindows(timestamps, at: path)
        #else
            try _setPOSIX(timestamps, at: path)
        #endif
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Metadata.Timestamps {
        internal static func _getPOSIX(_ path: File.Path) throws(Error) -> Self {
            var statBuf = stat()
            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            #if canImport(Darwin)
                let accessTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_atimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_atimespec.tv_nsec)
                )
                let modificationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_mtimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_mtimespec.tv_nsec)
                )
                let changeTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_ctimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_ctimespec.tv_nsec)
                )
                let creationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_birthtimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_birthtimespec.tv_nsec)
                )
                return Self(
                    accessTime: accessTime,
                    modificationTime: modificationTime,
                    changeTime: changeTime,
                    creationTime: creationTime
                )
            #else
                // Linux: no birthtime
                let accessTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_atim.tv_sec),
                    nanoseconds: Int(statBuf.st_atim.tv_nsec)
                )
                let modificationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_mtim.tv_sec),
                    nanoseconds: Int(statBuf.st_mtim.tv_nsec)
                )
                let changeTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_ctim.tv_sec),
                    nanoseconds: Int(statBuf.st_ctim.tv_nsec)
                )
                return Self(
                    accessTime: accessTime,
                    modificationTime: modificationTime,
                    changeTime: changeTime,
                    creationTime: nil
                )
            #endif
        }

        internal static func _setPOSIX(_ timestamps: Self, at path: File.Path) throws(Error) {
            var times = [timespec](repeating: timespec(), count: 2)

            // Access time
            times[0].tv_sec = time_t(timestamps.accessTime.secondsSinceEpoch)
            times[0].tv_nsec = Int(timestamps.accessTime.totalNanoseconds)

            // Modification time
            times[1].tv_sec = time_t(timestamps.modificationTime.secondsSinceEpoch)
            times[1].tv_nsec = Int(timestamps.modificationTime.totalNanoseconds)

            guard utimensat(AT_FDCWD, path.string, &times, 0) == 0 else {
                throw _mapErrno(errno, path: path)
            }
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .operationFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.System.Metadata.Timestamps {
        internal static func _getWindows(_ path: File.Path) throws(Error) -> Self {
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_READ_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { CloseHandle(handle) }

            var creationFT = FILETIME()
            var accessFT = FILETIME()
            var writeFT = FILETIME()

            guard _ok(GetFileTime(handle, &creationFT, &accessFT, &writeFT)) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            let creation = _fileTimeToTime(creationFT)
            let access = _fileTimeToTime(accessFT)
            let modification = _fileTimeToTime(writeFT)

            return Self(
                accessTime: access,
                modificationTime: modification,
                changeTime: modification,  // Windows doesn't have ctime
                creationTime: creation
            )
        }

        internal static func _setWindows(_ timestamps: Self, at path: File.Path) throws(Error) {
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_WRITE_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { CloseHandle(handle) }

            var accessFT = _timeToFileTime(timestamps.accessTime)
            var writeFT = _timeToFileTime(timestamps.modificationTime)

            // Pass nil for creation time to leave it unchanged
            guard _ok(SetFileTime(handle, nil, &accessFT, &writeFT)) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
        }

        /// Converts Windows FILETIME to Time.
        ///
        /// FILETIME is 100-nanosecond intervals since 1601-01-01.
        private static func _fileTimeToTime(_ ft: FILETIME) -> Time {
            // FILETIME is 100-nanosecond intervals since January 1, 1601
            // Unix epoch is January 1, 1970
            let intervals = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
            let unixIntervals = intervals - 116_444_736_000_000_000  // Difference between 1601 and 1970 in 100ns
            let seconds = Int(unixIntervals / 10_000_000)
            let nanoseconds = Int((unixIntervals % 10_000_000) * 100)
            return Time(__unchecked: (), secondsSinceEpoch: seconds, nanoseconds: nanoseconds)
        }

        /// Converts Time to Windows FILETIME.
        private static func _timeToFileTime(_ time: Time) -> FILETIME {
            let seconds = Int64(time.secondsSinceEpoch)
            let nanoseconds = Int64(time.totalNanoseconds)
            let intervals = (seconds * 10_000_000) + (nanoseconds / 100) + 116_444_736_000_000_000
            return FILETIME(
                dwLowDateTime: DWORD(intervals & 0xFFFF_FFFF),
                dwHighDateTime: DWORD((intervals >> 32) & 0xFFFF_FFFF)
            )
        }

        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            default:
                return .operationFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.System.Metadata.Timestamps.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let errno, let message):
            return "Operation failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Metadata.Type.swift
// ============================================================

//
//  File.System.Metadata.Kind.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Metadata {
    /// File type classification.
    public enum Kind: Sendable {
        case regular
        case directory
        case symbolicLink
        case blockDevice
        case characterDevice
        case fifo
        case socket
    }
}

// MARK: - RawRepresentable

extension File.System.Metadata.Kind: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .regular: return 0
        case .directory: return 1
        case .symbolicLink: return 2
        case .blockDevice: return 3
        case .characterDevice: return 4
        case .fifo: return 5
        case .socket: return 6
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .regular
        case 1: self = .directory
        case 2: self = .symbolicLink
        case 3: self = .blockDevice
        case 4: self = .characterDevice
        case 5: self = .fifo
        case 6: self = .socket
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Kind: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.System.Metadata.swift
// ============================================================

//
//  File.System.Metadata.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file metadata operations (permissions, timestamps, etc.).
    public enum Metadata {}
}

// ============================================================
// MARK: - File.System.Move+POSIX.swift
// ============================================================

//
//  File.System.Move+POSIX.swift
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

    extension File.System.Move {
        /// Moves a file using POSIX APIs.
        internal static func _movePOSIX(
            from source: File.Path,
            to destination: File.Path,
            options: Options
        ) throws(Error) {
            // Check if source exists
            var sourceStat = stat()
            guard stat(source.string, &sourceStat) == 0 else {
                throw _mapErrno(errno, source: source, destination: destination)
            }

            // Check if destination exists
            var destStat = stat()
            let destExists = stat(destination.string, &destStat) == 0

            if destExists && !options.overwrite {
                throw .destinationExists(destination)
            }

            // If overwrite is enabled and destination exists, remove it first
            // (rename on POSIX atomically replaces, but we check for option consistency)
            if destExists && options.overwrite {
                // rename() will atomically replace on same filesystem
            }

            // Try rename first (atomic, same device)
            if rename(source.string, destination.string) == 0 {
                return
            }

            let renameError = errno

            // If cross-device, fall back to copy+delete
            if renameError == EXDEV {
                try _copyAndDelete(from: source, to: destination, options: options)
                return
            }

            throw _mapErrno(renameError, source: source, destination: destination)
        }

        /// Fallback: copy then delete for cross-device moves.
        private static func _copyAndDelete(
            from source: File.Path,
            to destination: File.Path,
            options: Options
        ) throws(Error) {
            // Use Copy to copy the file
            let copyOptions = File.System.Copy.Options(
                overwrite: options.overwrite,
                copyAttributes: true,
                followSymlinks: true
            )

            do {
                try File.System.Copy._copyPOSIX(from: source, to: destination, options: copyOptions)
            } catch let copyError {
                // Map copy errors to move errors
                switch copyError {
                case .sourceNotFound(let path):
                    throw .sourceNotFound(path)
                case .destinationExists(let path):
                    throw .destinationExists(path)
                case .permissionDenied(let path):
                    throw .permissionDenied(path)
                case .isDirectory(let path):
                    throw .moveFailed(errno: EISDIR, message: "Is a directory: \(path)")
                case .copyFailed(let errno, let message):
                    throw .moveFailed(errno: errno, message: message)
                }
            }

            // Delete source
            if unlink(source.string) != 0 {
                // Source was copied but couldn't be deleted - log but don't fail
                // The move semantically succeeded (data is at destination)
            }
        }

        /// Maps errno to move error.
        private static func _mapErrno(
            _ errno: Int32,
            source: File.Path,
            destination: File.Path
        ) -> Error {
            switch errno {
            case ENOENT:
                return .sourceNotFound(source)
            case EEXIST:
                return .destinationExists(destination)
            case EACCES, EPERM:
                return .permissionDenied(source)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .moveFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Move+Windows.swift
// ============================================================

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

// ============================================================
// MARK: - File.System.Move.swift
// ============================================================

//
//  File.System.Move.swift
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

extension File.System {
    /// Namespace for file move/rename operations.
    public enum Move {}
}

// MARK: - Options

extension File.System.Move {
    /// Options for move operations.
    public struct Options: Sendable {
        /// Overwrite existing destination.
        public var overwrite: Bool

        public init(overwrite: Bool = false) {
            self.overwrite = overwrite
        }
    }
}

// MARK: - Error

extension File.System.Move {
    /// Errors that can occur during move operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case destinationExists(File.Path)
        case permissionDenied(File.Path)
        case moveFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Move {
    /// Moves (renames) a file from source to destination with options.
    ///
    /// - Parameters:
    ///   - source: The source file path.
    ///   - destination: The destination file path.
    ///   - options: Move options.
    /// - Throws: `File.System.Move.Error` on failure.
    public static func move(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init()
    ) throws(Error) {
        #if os(Windows)
            try _moveWindows(from: source, to: destination, options: options)
        #else
            try _movePOSIX(from: source, to: destination, options: options)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Move.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .sourceNotFound(let path):
            return "Source not found: \(path)"
        case .destinationExists(let path):
            return "Destination already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .moveFailed(let errno, let message):
            return "Move failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Parent.Check+POSIX.swift
// ============================================================

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
    ///   - dir: The path to verify.
    ///   - createIntermediates: If `true`, attempts to create the directory if it doesn't exist.
    /// - Throws: `File.System.Parent.Check.Error` if verification fails.
    static func verify(
        _ dir: String,
        createIntermediates: Bool
    ) throws(Error) {
        var st = stat()
        let rc = dir.withCString { stat($0, &st) }

        if rc != 0 {
            let e = errno
            let path = File.Path(__unchecked: (), dir)

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
            throw .notDirectory(path: File.Path(__unchecked: (), dir))
        }
    }

    private static func createParent(at path: File.Path) throws(Error) {
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

// ============================================================
// MARK: - File.System.Parent.Check+Windows.swift
// ============================================================

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
    ) throws(Error) {
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
            case _dword(ERROR_INVALID_NAME), _dword(ERROR_BAD_PATHNAME), _dword(ERROR_INVALID_DRIVE):
                throw .invalidPath(path: path)
            case _dword(ERROR_BAD_NETPATH), _dword(ERROR_BAD_NET_NAME):
                throw .networkPathNotFound(path: path)
            default:
                throw .statFailed(path: path, operation: .getFileAttributes, code: .windows(err))
            }
        }

        if (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) == 0 {
            throw .notDirectory(path: File.Path(__unchecked: (), dir))
        }
    }

    private static func createParent(at path: File.Path) throws(Error) {
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

// ============================================================
// MARK: - File.System.Parent.Check.swift
// ============================================================

//
//  File.System.Parent.Check.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.System {
    /// Parent directory operations.
    public enum Parent {}
}

extension File.System.Parent {
    /// Parent directory verification and creation.
    public enum Check {}
}

// MARK: - Operation

extension File.System.Parent.Check {
    /// The operation that was being performed when an error occurred.
    public enum Operation: String, Sendable {
        case stat = "stat(parent)"
        case getFileAttributes = "GetFileAttributesW(parent)"
    }
}

// MARK: - Error

extension File.System.Parent.Check {
    /// Errors that can occur during parent directory verification.
    public enum Error: Swift.Error, Equatable, Sendable {
        // Verification failures

        /// Access to the parent directory was denied.
        case accessDenied(path: File.Path)

        /// A component of the path exists but is not a directory.
        case notDirectory(path: File.Path)

        /// The parent directory does not exist.
        case missing(path: File.Path)

        /// A system call failed with an unclassified error code.
        case statFailed(path: File.Path, operation: Operation, code: File.System.Error.Code)

        /// The path is malformed or contains invalid characters.
        case invalidPath(path: File.Path)

        /// A network path could not be found (Windows only).
        case networkPathNotFound(path: File.Path)

        // Creation failures (when createIntermediates = true)

        /// Failed to create the parent directory.
        case creationFailed(path: File.Path, underlying: File.System.Create.Directory.Error)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Parent.Check.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .accessDenied(let path):
            return "Access denied to parent directory: \(path)"
        case .notDirectory(let path):
            return "Path component is not a directory: \(path)"
        case .missing(let path):
            return "Parent directory not found: \(path)"
        case .statFailed(let path, let operation, let code):
            return "\(operation.rawValue) failed for \(path): \(code)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .networkPathNotFound(let path):
            return "Network path not found: \(path)"
        case .creationFailed(let path, let underlying):
            return "Failed to create parent directory \(path): \(underlying)"
        }
    }
}

// ============================================================
// MARK: - File.System.Read.Buffered.swift
// ============================================================

//
//  File.System.Read.Buffered.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Read {
    /// Buffered file reading for efficient I/O.
    public enum Buffered {
        // TODO: Implementation
    }
}

// ============================================================
// MARK: - File.System.Read.Full+POSIX.swift
// ============================================================

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
        internal static func _readPOSIX(from path: File.Path) throws(Error) -> [UInt8] {
            // Open file for reading
            let fd = open(path.string, O_RDONLY)
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

// ============================================================
// MARK: - File.System.Read.Full+Windows.swift
// ============================================================

//
//  File.System.Read.Full+Windows.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if os(Windows)

    import WinSDK

    extension File.System.Read.Full {
        /// Reads file contents using Windows APIs.
        internal static func _readWindows(from path: File.Path) throws(Error) -> [UInt8] {
            // Open file for reading
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _dword(GENERIC_READ),
                    _mask(FILE_SHARE_READ),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            defer { CloseHandle(handle) }

            // Get file size
            var fileSize: LARGE_INTEGER = LARGE_INTEGER()
            guard _ok(GetFileSizeEx(handle, &fileSize)) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            let size = Int(fileSize.QuadPart)

            // Handle empty file
            if size == 0 {
                return []
            }

            // Allocate buffer and read
            var buffer = [UInt8](repeating: 0, count: size)
            var totalRead: DWORD = 0

            let success = buffer.withUnsafeMutableBufferPointer { ptr in
                ReadFile(
                    handle,
                    ptr.baseAddress,
                    DWORD(truncatingIfNeeded: size),
                    &totalRead,
                    nil
                )
            }

            guard _ok(success) else {
                throw _mapWindowsError(GetLastError(), path: path)
            }

            // Trim buffer if we read less than expected
            if Int(totalRead) < size {
                buffer.removeLast(size - Int(totalRead))
            }

            return buffer
        }

        /// Maps Windows error to read error.
        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            case _dword(ERROR_TOO_MANY_OPEN_FILES):
                return .tooManyOpenFiles
            default:
                return .readFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Read.Full.swift
// ============================================================

//
//  File.System.Read.Full.swift
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

extension File.System.Read {
    /// Read entire file contents into memory.
    public enum Full {}
}

// MARK: - Error

extension File.System.Read.Full {
    /// Errors that can occur during full file read operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case readFailed(errno: Int32, message: String)
        case tooManyOpenFiles
    }
}

// MARK: - Core API

extension File.System.Read.Full {
    /// Reads the entire contents of a file into memory.
    ///
    /// This is the core read primitive - reads all bytes from a file.
    ///
    /// - Parameter path: The path to the file to read.
    /// - Returns: The file contents as an array of bytes.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    public static func read(from path: File.Path) throws(Error) -> [UInt8] {
        #if os(Windows)
            return try _readWindows(from: path)
        #else
            return try _readPOSIX(from: path)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Read.Full.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        case .tooManyOpenFiles:
            return "Too many open files"
        }
    }
}

// ============================================================
// MARK: - File.System.Read.Streaming.swift
// ============================================================

//
//  File.System.Read.Streaming.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Read {
    /// Streaming/chunked file reading.
    public enum Streaming {
        // TODO: Implementation
    }
}

// ============================================================
// MARK: - File.System.Read.swift
// ============================================================

//
//  File.System.Read.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file read operations.
    public enum Read {}
}

// ============================================================
// MARK: - File.System.Stat+POSIX.swift
// ============================================================

//
//  File.System.Stat+POSIX.swift
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

    @_spi(Internal) import StandardTime

    extension File.System.Stat {
        /// Gets file info using POSIX stat (follows symlinks).
        internal static func _infoPOSIX(
            at path: File.Path
        ) throws(Error) -> File.System.Metadata.Info {
            var statBuf = stat()

            guard stat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            return _makeInfo(from: statBuf)
        }

        /// Gets file info using POSIX lstat (does not follow symlinks).
        ///
        /// Returns info about the symlink itself rather than its target.
        internal static func _lstatInfoPOSIX(
            at path: File.Path
        ) throws(Error) -> File.System.Metadata.Info {
            var statBuf = stat()

            guard lstat(path.string, &statBuf) == 0 else {
                throw _mapErrno(errno, path: path)
            }

            return _makeInfo(from: statBuf)
        }

        /// Checks if path exists using POSIX access.
        internal static func _existsPOSIX(at path: File.Path) -> Bool {
            access(path.string, F_OK) == 0
        }

        /// Checks if path is a symlink using POSIX lstat.
        internal static func _isSymlinkPOSIX(at path: File.Path) -> Bool {
            var statBuf = stat()
            guard lstat(path.string, &statBuf) == 0 else {
                return false
            }
            return (statBuf.st_mode & S_IFMT) == S_IFLNK
        }

        /// Creates Info from stat buffer.
        private static func _makeInfo(from statBuf: stat) -> File.System.Metadata.Info {
            let fileType: File.System.Metadata.Kind
            switch statBuf.st_mode & S_IFMT {
            case S_IFREG:
                fileType = .regular
            case S_IFDIR:
                fileType = .directory
            case S_IFLNK:
                fileType = .symbolicLink
            case S_IFBLK:
                fileType = .blockDevice
            case S_IFCHR:
                fileType = .characterDevice
            case S_IFIFO:
                fileType = .fifo
            case S_IFSOCK:
                fileType = .socket
            default:
                fileType = .regular
            }

            let permissions = File.System.Metadata.Permissions(
                rawValue: UInt16(statBuf.st_mode & 0o7777)
            )

            let ownership = File.System.Metadata.Ownership(
                uid: statBuf.st_uid,
                gid: statBuf.st_gid
            )

            #if canImport(Darwin)
                let accessTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_atimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_atimespec.tv_nsec)
                )
                let modificationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_mtimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_mtimespec.tv_nsec)
                )
                let changeTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_ctimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_ctimespec.tv_nsec)
                )
                let creationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_birthtimespec.tv_sec),
                    nanoseconds: Int(statBuf.st_birthtimespec.tv_nsec)
                )
                let timestamps = File.System.Metadata.Timestamps(
                    accessTime: accessTime,
                    modificationTime: modificationTime,
                    changeTime: changeTime,
                    creationTime: creationTime
                )
            #else
                let accessTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_atim.tv_sec),
                    nanoseconds: Int(statBuf.st_atim.tv_nsec)
                )
                let modificationTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_mtim.tv_sec),
                    nanoseconds: Int(statBuf.st_mtim.tv_nsec)
                )
                let changeTime = Time(
                    __unchecked: (),
                    secondsSinceEpoch: Int(statBuf.st_ctim.tv_sec),
                    nanoseconds: Int(statBuf.st_ctim.tv_nsec)
                )
                let timestamps = File.System.Metadata.Timestamps(
                    accessTime: accessTime,
                    modificationTime: modificationTime,
                    changeTime: changeTime,
                    creationTime: nil
                )
            #endif

            return File.System.Metadata.Info(
                size: Int64(statBuf.st_size),
                permissions: permissions,
                owner: ownership,
                timestamps: timestamps,
                type: fileType,
                inode: UInt64(statBuf.st_ino),
                deviceId: UInt64(statBuf.st_dev),
                linkCount: UInt32(statBuf.st_nlink)
            )
        }

        /// Maps errno to stat error.
        internal static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .statFailed(errno: errno, message: message)
            }
        }
    }

#endif

// ============================================================
// MARK: - File.System.Stat+Windows.swift
// ============================================================

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
        /// Gets file info using Windows APIs.
        @usableFromInline
        internal static func _infoWindows(
            at path: File.Path
        ) throws(Error) -> File.System.Metadata.Info {
            var findData = WIN32_FIND_DATAW()

            let findHandle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard findHandle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            FindClose(findHandle)

            // Best-effort file identity: try to get volume serial + file index
            let (deviceId, fileIndex) = _getFileIdentity(at: path)

            return _makeInfo(from: findData, deviceId: deviceId, fileIndex: fileIndex)
        }

        /// Gets file identity (volume serial + file index) for cycle detection.
        ///
        /// Uses GetFileInformationByHandle to get stable identity that works
        /// even for junctions and symlinks. Returns (0, 0) if unavailable.
        @usableFromInline
        internal static func _getFileIdentity(
            at path: File.Path
        ) -> (deviceId: UInt64, fileIndex: UInt64) {
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    0,  // No access needed, just querying info
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS),  // Required for directories
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
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }
            return attrs != INVALID_FILE_ATTRIBUTES
        }

        /// Checks if path is a symlink using Windows APIs.
        @usableFromInline
        internal static func _isSymlinkWindows(at path: File.Path) -> Bool {
            let attrs = path.string.withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }
            guard attrs != INVALID_FILE_ATTRIBUTES else { return false }
            return (attrs & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0
        }

        /// Creates Info from Windows find data.
        @usableFromInline
        internal static func _makeInfo(
            from data: WIN32_FIND_DATAW,
            deviceId: UInt64 = 0,
            fileIndex: UInt64 = 0
        ) -> File.System.Metadata.Info {
            let fileType: File.System.Metadata.FileType
            if (data.dwFileAttributes & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                fileType = .directory
            } else if (data.dwFileAttributes & _mask(FILE_ATTRIBUTE_REPARSE_POINT)) != 0 {
                fileType = .symbolicLink
            } else {
                fileType = .regular
            }

            // Windows doesn't have POSIX permissions, default to 644
            let permissions = File.System.Metadata.Permissions.defaultFile

            // Windows doesn't expose uid/gid
            let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

            let size = Int64(data.nFileSizeHigh) << 32 | Int64(data.nFileSizeLow)

            let timestamps = File.System.Metadata.Timestamps(
                accessTime: _fileTimeToUnix(data.ftLastAccessTime),
                modificationTime: _fileTimeToUnix(data.ftLastWriteTime),
                changeTime: _fileTimeToUnix(data.ftLastWriteTime),
                creationTime: _fileTimeToUnix(data.ftCreationTime)
            )

            return File.System.Metadata.Info(
                size: size,
                permissions: permissions,
                owner: ownership,
                timestamps: timestamps,
                type: fileType,
                inode: fileIndex,  // Windows file index serves as inode equivalent
                deviceId: deviceId,  // Volume serial number
                linkCount: 1
            )
        }

        /// Converts Windows FILETIME to Time.
        ///
        /// FILETIME is 100-nanosecond intervals since 1601-01-01.
        @usableFromInline
        internal static func _fileTimeToUnix(_ ft: FILETIME) -> Time {
            // FILETIME is 100-nanosecond intervals since January 1, 1601
            // Unix epoch is January 1, 1970
            let intervals = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
            let unixIntervals = intervals - 116_444_736_000_000_000  // Difference between 1601 and 1970 in 100ns
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

// ============================================================
// MARK: - File.System.Stat.swift
// ============================================================

//
//  File.System.Stat.swift
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

extension File.System {
    /// File status and existence checks.
    public enum Stat {}
}

// MARK: - Error

extension File.System.Stat {
    /// Errors that can occur during stat operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case statFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Stat {
    /// Gets file metadata information (follows symlinks).
    ///
    /// - Parameter path: The path to stat.
    /// - Returns: File metadata information.
    /// - Throws: `File.System.Stat.Error` on failure.
    public static func info(at path: File.Path) throws(Error) -> File.System.Metadata.Info {
        #if os(Windows)
            return try _infoWindows(at: path)
        #else
            return try _infoPOSIX(at: path)
        #endif
    }

    /// Gets file metadata information without following symlinks.
    ///
    /// For symlinks, returns info about the link itself rather than its target.
    /// Useful for cycle detection when walking directories with `followSymlinks`.
    ///
    /// - Parameter path: The path to stat.
    /// - Returns: File metadata information for the link itself.
    /// - Throws: `File.System.Stat.Error` on failure.
    public static func lstatInfo(at path: File.Path) throws(Error) -> File.System.Metadata.Info {
        #if os(Windows)
            // Windows: GetFileAttributesEx doesn't follow symlinks by default
            return try _infoWindows(at: path)
        #else
            return try _lstatInfoPOSIX(at: path)
        #endif
    }

    /// Checks if a path exists.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path exists, `false` otherwise.
    public static func exists(at path: File.Path) -> Bool {
        #if os(Windows)
            return _existsWindows(at: path)
        #else
            return _existsPOSIX(at: path)
        #endif
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Stat.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .statFailed(let errno, let message):
            return "Stat failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Append.swift
// ============================================================

//
//  File.System.Write.Append.swift
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

extension File.System.Write {
    /// Append data to existing files.
    public enum Append {}
}

// MARK: - Error

extension File.System.Write.Append {
    /// Errors that can occur during append operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case writeFailed(errno: Int32, message: String)
    }
}

// MARK: - Core API

extension File.System.Write.Append {
    /// Appends bytes to a file.
    ///
    /// Creates the file if it doesn't exist.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to append.
    ///   - path: The file path.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public static func append(
        _ bytes: borrowing Span<UInt8>,
        to path: File.Path
    ) throws(Error) {
        #if os(Windows)
            try _appendWindows(bytes, to: path)
        #else
            try _appendPOSIX(bytes, to: path)
        #endif
    }

}

// MARK: - Binary.Serializable

extension File.System.Write.Append {
    /// Appends a Binary.Serializable value to a file.
    ///
    /// - Parameters:
    ///   - value: The serializable value to append.
    ///   - path: The file path.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public static func append<S: Binary.Serializable>(
        _ value: S,
        to path: File.Path
    ) throws(Error) {
        try S.withSerializedBytes(value) { (span: borrowing Span<UInt8>) throws(Error) in
            try append(span, to: path)
        }
    }

}

// MARK: - POSIX Implementation

#if !os(Windows)
    extension File.System.Write.Append {
        internal static func _appendPOSIX(
            _ bytes: borrowing Span<UInt8>,
            to path: File.Path
        ) throws(Error) {
            let fd = open(path.string, O_WRONLY | O_CREAT | O_APPEND, 0o644)
            guard fd >= 0 else {
                throw _mapErrno(errno, path: path)
            }
            defer { _ = close(fd) }

            let count = bytes.count
            if count == 0 { return }

            try bytes.withUnsafeBufferPointer { buffer throws(Error) in
                guard let base = buffer.baseAddress else { return }

                var written = 0
                while written < count {
                    let remaining = count - written
                    #if canImport(Darwin)
                        let w = Darwin.write(fd, base.advanced(by: written), remaining)
                    #elseif canImport(Glibc)
                        let w = Glibc.write(fd, base.advanced(by: written), remaining)
                    #elseif canImport(Musl)
                        let w = Musl.write(fd, base.advanced(by: written), remaining)
                    #endif

                    if w > 0 {
                        written += w
                    } else if w < 0 {
                        if errno == EINTR { continue }
                        throw _mapErrno(errno, path: path)
                    }
                }
            }
        }

        private static func _mapErrno(_ errno: Int32, path: File.Path) -> Error {
            switch errno {
            case ENOENT:
                return .pathNotFound(path)
            case EACCES, EPERM:
                return .permissionDenied(path)
            case EISDIR:
                return .isDirectory(path)
            default:
                let message: String
                if let cString = strerror(errno) {
                    message = String(cString: cString)
                } else {
                    message = "Unknown error"
                }
                return .writeFailed(errno: errno, message: message)
            }
        }
    }
#endif

// MARK: - Windows Implementation

#if os(Windows)
    extension File.System.Write.Append {
        internal static func _appendWindows(
            _ bytes: borrowing Span<UInt8>,
            to path: File.Path
        ) throws(Error) {
            let handle = path.string.withCString(encodedAs: UTF16.self) { wpath in
                CreateFileW(
                    wpath,
                    _mask(FILE_APPEND_DATA),
                    _mask(FILE_SHARE_READ),
                    nil,
                    _dword(OPEN_ALWAYS),
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                throw _mapWindowsError(GetLastError(), path: path)
            }
            defer { CloseHandle(handle) }

            let count = bytes.count
            if count == 0 { return }

            try bytes.withUnsafeBufferPointer { buffer throws(Error) in
                guard let base = buffer.baseAddress else { return }

                var written: DWORD = 0
                let success = WriteFile(
                    handle,
                    base,
                    DWORD(truncatingIfNeeded: count),
                    &written,
                    nil
                )

                guard _ok(success) && written == count else {
                    throw _mapWindowsError(GetLastError(), path: path)
                }
            }
        }

        private static func _mapWindowsError(_ error: DWORD, path: File.Path) -> Error {
            switch error {
            case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                return .pathNotFound(path)
            case _dword(ERROR_ACCESS_DENIED):
                return .permissionDenied(path)
            default:
                return .writeFailed(errno: Int32(error), message: "Windows error \(error)")
            }
        }
    }
#endif

// MARK: - CustomStringConvertible for Error

extension File.System.Write.Append.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .writeFailed(let errno, let message):
            return "Write failed: \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic+POSIX.swift
// ============================================================

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
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

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

        /// Verifies the parent directory exists and is accessible, optionally creating it.
        private static func verifyOrCreateParentDirectory(
            _ dir: String,
            createIntermediates: Bool
        ) throws(File.System.Write.Atomic.Error) {
            do {
                try File.System.Parent.Check.verify(dir, createIntermediates: createIntermediates)
            } catch let e {
                throw .parent(e)
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

// ============================================================
// MARK: - File.System.Write.Atomic+Windows.swift
// ============================================================

// File.System.Write.Atomic+Windows.swift
// Windows implementation of atomic file writes

#if os(Windows)

    import WinSDK
    import INCITS_4_1986
    import RFC_4648

    // MARK: - Windows Implementation

    enum WindowsAtomic {

        static func writeSpan(
            _ bytes: borrowing Swift.Span<UInt8>,
            to path: borrowing String,
            options: borrowing File.System.Write.Atomic.Options
        ) throws(File.System.Write.Atomic.Error) {
            typealias Phase = File.System.Write.Atomic.Commit.Phase

            // Track progress for cleanup and error diagnostics
            var phase: Phase = .pending

            // 1. Resolve and validate parent directory
            let resolvedPath = normalizePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

            // 2. Generate unique temp file path
            let tempPath = generateTempPath(in: parent, for: resolvedPath)

            // 3. Open destination for metadata if it exists
            let (destExists, destHandle) = try openDestinationForMetadata(
                path: resolvedPath,
                options: options
            )
            defer { if let h = destHandle { _ = CloseHandle(h) } }

            // 4. Create temp file
            let tempHandle = try createTempFile(at: tempPath)
            phase = .writing

            defer {
                // CRITICAL: After renamedPublished, NEVER delete destination!
                // Only cleanup temp file if rename hasn't happened yet.
                if phase < .closed {
                    _ = CloseHandle(tempHandle)
                }
                if phase < .renamedPublished {
                    _ = deleteFile(tempPath)
                }
                // Note: if phase >= .renamedPublished, temp no longer exists (was renamed)
            }

            // 5. Write all data
            try writeAll(bytes, to: tempHandle)

            // 6. Flush to disk
            try flushFile(tempHandle, durability: options.durability)
            phase = .syncedFile

            // 7. Copy metadata if requested
            if destExists, let srcHandle = destHandle {
                try copyMetadata(from: srcHandle, to: tempHandle, options: options)
            }

            // 8. Close temp file before rename
            guard _ok(CloseHandle(tempHandle)) else {
                throw .closeFailed(
                    code: .windows(GetLastError()),
                    message: "CloseHandle failed"
                )
            }
            phase = .closed

            // 9. Atomic rename
            try atomicRename(from: tempPath, to: resolvedPath, options: options)
            // CRITICAL: Update phase IMMEDIATELY after successful rename
            phase = .renamedPublished

            // 10. Flush directory - only for .full durability.
            // Directory sync is a metadata persistence step, so it should NOT be
            // performed for .dataOnly (which explicitly states "metadata may not
            // be persisted"). If this fails after publish, the file IS published
            // but durability is not guaranteed.
            if options.durability == .full {
                phase = .directorySyncAttempted  // Mark attempt BEFORE syscall
                do {
                    try flushDirectory(parent)
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

    extension WindowsAtomic {

        /// Normalizes a Windows path.
        private static func normalizePath(_ path: String) -> String {
            // Convert forward slashes to backslashes manually (no Foundation)
            var result = ""
            result.reserveCapacity(path.utf8.count)  // Pre-reserve to avoid reallocations
            for char in path {
                if char == "/" {
                    result.append("\\")
                } else {
                    result.append(char)
                }
            }

            // Remove trailing backslashes (except for root like "C:\")
            while result.count > 3 && result.hasSuffix("\\") {
                result.removeLast()
            }

            return result
        }

        /// Extracts parent directory from a Windows path.
        private static func parentDirectory(of path: String) -> String {
            // Handle UNC paths, drive letters, etc.
            if let lastSep = path.lastIndex(of: "\\") {
                if lastSep == path.startIndex {
                    return String(path[...lastSep])
                }
                // Check for "C:\" case
                let prefix = String(path[..<lastSep])
                if prefix.count == 2 && prefix.last == ":" {
                    return prefix + "\\"
                }
                return prefix
            }
            return "."
        }

        /// Extracts filename from a path.
        private static func fileName(of path: String) -> String {
            if let lastSep = path.lastIndex(of: "\\") {
                return String(path[path.index(after: lastSep)...])
            }
            return path
        }

        /// Verifies parent directory exists, optionally creating it.
        private static func verifyOrCreateParentDirectory(
            _ dir: String,
            createIntermediates: Bool
        ) throws(File.System.Write.Atomic.Error) {
            do {
                try File.System.Parent.Check.verify(dir, createIntermediates: createIntermediates)
            } catch let e {
                throw .parent(e)
            }
        }

        /// Generates a unique temp file path.
        private static func generateTempPath(in parent: String, for destPath: String) -> String {
            let baseName = fileName(of: destPath)
            let random = randomHex(12)
            return "\(parent)\\\(baseName).atomic.\(random).tmp"
        }

        /// Counter for uniqueness within same tick.
        private nonisolated(unsafe) static var _counter: UInt32 = 0

        /// Generates a unique hex string for temp file naming.
        /// Uses process ID, tick count, and counter for uniqueness.
        private static func randomHex(_ byteCount: Int) -> String {
            let pid = GetCurrentProcessId()
            let tick = GetTickCount64()
            _counter &+= 1

            // Build hex string from these values using INCITS_4_1986 ASCII constants
            let digit0 = UInt32(UInt8.ascii.`0`)
            let letterA = UInt32(UInt8.ascii.a)

            var result = ""
            let value = UInt64(pid) ^ tick ^ UInt64(_counter)
            var remaining = value
            for _ in 0..<min(byteCount * 2, 16) {
                let nibble = UInt32(remaining & 0xF)
                let code = nibble < 10 ? (digit0 + nibble) : (letterA - 10 + nibble)
                result.append(Character(Unicode.Scalar(code)!))
                remaining >>= 4
            }
            return result
        }
    }

    // MARK: - File Operations

    extension WindowsAtomic {

        /// Opens destination file for reading metadata, if it exists.
        private static func openDestinationForMetadata(
            path: String,
            options: File.System.Write.Atomic.Options
        ) throws(File.System.Write.Atomic.Error) -> (exists: Bool, handle: HANDLE?) {

            let attrs = withWideString(path) { GetFileAttributesW($0) }
            let exists = (attrs != INVALID_FILE_ATTRIBUTES)

            if !exists {
                return (false, nil)
            }

            // Only open if we need metadata
            if !options.preservePermissions && !options.preserveTimestamps {
                return (true, nil)
            }

            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _mask(READ_CONTROL) | _mask(FILE_READ_ATTRIBUTES),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                // Can't read metadata, but file exists
                return (true, nil)
            }

            return (true, handle)
        }

        /// Creates a new temp file for writing.
        private static func createTempFile(
            at path: String
        ) throws(File.System.Write.Atomic.Error) -> HANDLE {
            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _dword(GENERIC_WRITE) | _dword(GENERIC_READ),
                    _mask(FILE_SHARE_READ),
                    nil,
                    _dword(CREATE_NEW),
                    _mask(FILE_ATTRIBUTE_TEMPORARY),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                let err = GetLastError()
                throw .tempFileCreationFailed(
                    directory: File.Path(__unchecked: (), parentDirectory(of: path)),
                    code: .windows(err),
                    message: "CreateFileW failed with error \(err)"
                )
            }

            return handle
        }

        /// Writes all bytes to handle.
        private static func writeAll(
            _ bytes: borrowing Swift.Span<UInt8>,
            to handle: HANDLE
        ) throws(File.System.Write.Atomic.Error) {
            let total = bytes.count
            if total == 0 { return }

            var written = 0

            try bytes.withUnsafeBufferPointer { buffer throws(File.System.Write.Atomic.Error) in
                guard let base = buffer.baseAddress else {
                    throw .writeFailed(
                        bytesWritten: 0,
                        bytesExpected: total,
                        code: .windows(0),
                        message: "nil buffer"
                    )
                }

                while written < total {
                    let remaining = total - written
                    var bytesWritten: DWORD = 0

                    let success = WriteFile(
                        handle,
                        UnsafeRawPointer(base.advanced(by: written)),
                        DWORD(truncatingIfNeeded: remaining),
                        &bytesWritten,
                        nil
                    )

                    if !_ok(success) {
                        let err = GetLastError()
                        throw .writeFailed(
                            bytesWritten: written,
                            bytesExpected: total,
                            code: .windows(err),
                            message: "WriteFile failed with error \(err)"
                        )
                    }

                    if bytesWritten == 0 {
                        throw .writeFailed(
                            bytesWritten: written,
                            bytesExpected: total,
                            code: .windows(0),
                            message: "WriteFile wrote 0 bytes"
                        )
                    }

                    written += Int(bytesWritten)
                }
            }
        }

        /// Flushes file buffers to disk based on durability mode.
        private static func flushFile(
            _ handle: HANDLE,
            durability: File.System.Write.Atomic.Durability
        ) throws(File.System.Write.Atomic.Error) {
            switch durability {
            case .full, .dataOnly:
                // Windows FlushFileBuffers is equivalent to full sync
                // (there's no separate metadata-only sync on Windows like fdatasync)
                if !_ok(FlushFileBuffers(handle)) {
                    let err = GetLastError()
                    throw .syncFailed(
                        code: .windows(err),
                        message: "FlushFileBuffers failed with error \(err)"
                    )
                }
            case .none:
                // No sync - fastest but no crash-safety guarantees
                break
            }
        }

        /// Deletes a file.
        private static func deleteFile(_ path: String) -> Bool {
            return withWideString(path) { DeleteFileW($0) }
        }
    }

    // MARK: - Atomic Rename

    extension WindowsAtomic {

        /// Performs atomic rename, optionally replacing existing file.
        private static func atomicRename(
            from tempPath: String,
            to destPath: String,
            options: File.System.Write.Atomic.Options
        ) throws(File.System.Write.Atomic.Error) {

            let replace = (options.strategy == .replaceExisting)

            // Try modern SetFileInformationByHandle first
            if trySetFileInfoRename(from: tempPath, to: destPath, replace: replace) {
                return
            }

            // Fallback to MoveFileExW
            let flags: DWORD =
                replace
                ? _dword(MOVEFILE_REPLACE_EXISTING) | _dword(MOVEFILE_WRITE_THROUGH)
                : _dword(MOVEFILE_WRITE_THROUGH)

            let success = withWideString(tempPath) { wTemp in
                withWideString(destPath) { wDest in
                    MoveFileExW(wTemp, wDest, flags)
                }
            }

            if !success {
                let err = GetLastError()

                // Check for destination exists in noClobber mode
                // Multiple error codes can indicate "exists":
                // - ERROR_ALREADY_EXISTS (183)
                // - ERROR_FILE_EXISTS (80)
                // Note: ERROR_ACCESS_DENIED can occur for various reasons,
                // so we don't map it to destinationExists to avoid masking real permission errors
                if !replace && (err == _dword(ERROR_ALREADY_EXISTS) || err == _dword(ERROR_FILE_EXISTS)) {
                    throw .destinationExists(path: File.Path(__unchecked: (), destPath))
                }

                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    code: .windows(err),
                    message: "MoveFileExW failed with error \(err)"
                )
            }
        }

        /// Tries to use SetFileInformationByHandle for rename.
        private static func trySetFileInfoRename(
            from tempPath: String,
            to destPath: String,
            replace: Bool
        ) -> Bool {
            // Open temp file for rename operation
            let tempHandle = withWideString(tempPath) { wTemp in
                CreateFileW(
                    wTemp,
                    _mask(DELETE) | _mask(SYNCHRONIZE),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }

            guard let tempHandle = tempHandle, tempHandle != INVALID_HANDLE_VALUE else {
                return false
            }
            defer { _ = CloseHandle(tempHandle) }

            // Use withCString to avoid intermediate Array allocation for destPath
            return destPath.withCString(encodedAs: UTF16.self) { destWide in
                let nameByteCount = (destPath.utf16.count + 1) * MemoryLayout<WCHAR>.size

                // Calculate struct offset carefully - offset(of:) may not work for C-imported structs
                // If offset(of:) returns nil, fall back to MoveFileExW (graceful degradation)
                guard let fileNameOffset = MemoryLayout<FILE_RENAME_INFO>.offset(of: \.FileName)
                else {
                    // Struct layout unavailable at runtime - fall back to MoveFileExW
                    return false
                }
                let totalSize = fileNameOffset + nameByteCount

                // Use correct alignment for the struct
                let alignment = max(
                    MemoryLayout<FILE_RENAME_INFO>.alignment,
                    MemoryLayout<WCHAR>.alignment
                )
                let buffer = UnsafeMutableRawPointer.allocate(
                    byteCount: totalSize,
                    alignment: alignment
                )
                defer { buffer.deallocate() }

                // Initialize only the header portion, not the entire buffer
                // (avoiding large zero-init that we're eliminating elsewhere)
                let headerSize = MemoryLayout<FILE_RENAME_INFO>.size
                buffer.initializeMemory(
                    as: UInt8.self,
                    repeating: 0,
                    count: min(headerSize, totalSize)
                )

                // Fill in the structure
                let info = buffer.assumingMemoryBound(to: FILE_RENAME_INFO.self)
                info.pointee.Flags = replace ? _dword(FILE_RENAME_FLAG_REPLACE_IF_EXISTS) : 0
                info.pointee.RootDirectory = nil
                info.pointee.FileNameLength = DWORD(
                    truncatingIfNeeded: nameByteCount - MemoryLayout<WCHAR>.size
                )

                // Copy UTF-16 path into struct tail
                let fileNamePtr = buffer.advanced(by: fileNameOffset).assumingMemoryBound(
                    to: WCHAR.self
                )
                var i = 0
                var ptr = destWide
                while ptr.pointee != 0 {
                    fileNamePtr[i] = WCHAR(ptr.pointee)
                    ptr += 1
                    i += 1
                }
                fileNamePtr[i] = 0  // null terminator

                let success = SetFileInformationByHandle(
                    tempHandle,
                    FileRenameInfoEx,
                    buffer,
                    DWORD(truncatingIfNeeded: totalSize)
                )

                return _ok(success)
            }
        }

        /// Flushes directory to persist rename.
        private static func flushDirectory(_ path: String) throws(File.System.Write.Atomic.Error) {
            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _dword(GENERIC_READ),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                let err = GetLastError()
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    code: .windows(err),
                    message: "CreateFileW(directory) failed with error \(err)"
                )
            }
            defer { _ = CloseHandle(handle) }

            if !_ok(FlushFileBuffers(handle)) {
                let err = GetLastError()
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    code: .windows(err),
                    message: "FlushFileBuffers(directory) failed with error \(err)"
                )
            }
        }
    }

    // MARK: - Metadata Preservation

    extension WindowsAtomic {

        /// Copies metadata from source handle to destination handle.
        private static func copyMetadata(
            from srcHandle: HANDLE,
            to dstHandle: HANDLE,
            options: File.System.Write.Atomic.Options
        ) throws(File.System.Write.Atomic.Error) {

            // Copy timestamps (includes creation time, access time, write time)
            if options.preserveTimestamps {
                var basicInfo = FILE_BASIC_INFO()

                let getSuccess = GetFileInformationByHandleEx(
                    srcHandle,
                    FileBasicInfo,
                    &basicInfo,
                    DWORD(truncatingIfNeeded: MemoryLayout<FILE_BASIC_INFO>.size)
                )

                if !_ok(getSuccess) {
                    let err = GetLastError()
                    throw .metadataPreservationFailed(
                        operation: "GetFileInformationByHandleEx",
                        code: .windows(err),
                        message: "Failed to get file info with error \(err)"
                    )
                }

                let setSuccess = SetFileInformationByHandle(
                    dstHandle,
                    FileBasicInfo,
                    &basicInfo,
                    DWORD(truncatingIfNeeded: MemoryLayout<FILE_BASIC_INFO>.size)
                )

                if !_ok(setSuccess) {
                    let err = GetLastError()
                    throw .metadataPreservationFailed(
                        operation: "SetFileInformationByHandle",
                        code: .windows(err),
                        message: "Failed to set file info with error \(err)"
                    )
                }
            }

            // Windows security descriptors (ACLs, owner, etc.)
            #if ATOMICFILEWRITE_HAS_WINDOWS_SECURITY_SHIM
                if options.preservePermissions {
                    var winErr: DWORD = 0
                    if atomicfilewrite_copy_security_descriptor(srcHandle, dstHandle, &winErr) == 0
                    {
                        throw .metadataPreservationFailed(
                            operation: "SecurityDescriptor",
                            code: .windows(winErr),
                            message: "Security descriptor copy failed with error \(winErr)"
                        )
                    }
                }
            #endif
        }

        #if ATOMICFILEWRITE_HAS_WINDOWS_SECURITY_SHIM
            @_silgen_name("atomicfilewrite_copy_security_descriptor")
            private static func atomicfilewrite_copy_security_descriptor(
                _ srcHandle: HANDLE,
                _ dstHandle: HANDLE,
                _ outWinErr: UnsafeMutablePointer<DWORD>
            ) -> Int32
        #endif
    }

    // MARK: - Utilities

    extension WindowsAtomic {

        /// Executes a closure with a wide (UTF-16) string.
        /// Uses String.withCString(encodedAs:) to avoid intermediate Array allocation.
        private static func withWideString<T>(
            _ string: String,
            _ body: (UnsafePointer<WCHAR>) -> T
        ) -> T {
            string.withCString(encodedAs: UTF16.self) { utf16Ptr in
                // UTF16.CodeUnit is UInt16, WCHAR is also UInt16 on Windows
                // withCString provides null-terminated buffer
                utf16Ptr.withMemoryRebound(to: WCHAR.self, capacity: string.utf16.count + 1) {
                    wcharPtr in
                    body(wcharPtr)
                }
            }
        }
    }

#endif  // os(Windows)

// ============================================================
// MARK: - File.System.Write.Atomic.Commit.Phase.swift
// ============================================================

//
//  File.System.Write.Atomic.Commit.Phase.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic.Commit {
    /// Tracks progress through the atomic write operation.
    ///
    /// Use `published` to determine if the file exists at its destination after failure.
    /// Use `durabilityAttempted` for postmortem diagnostics.
    ///
    /// ## Usage
    /// After catching an error, check the phase to understand the file state:
    /// ```swift
    /// do {
    ///     try atomicWrite(data, to: path)
    /// } catch {
    ///     if phase.published {
    ///         // File exists at destination, but durability may be compromised
    ///     } else {
    ///         // File was NOT written to destination
    ///     }
    /// }
    /// ```
    public enum Phase: UInt8, Sendable, Equatable {
        /// Operation not yet started.
        case pending = 0

        /// Writing data to temp file.
        case writing = 1

        /// File data synced to disk.
        case syncedFile = 2

        /// Temp file closed.
        case closed = 3

        /// File atomically renamed to destination (published).
        case renamedPublished = 4

        /// Directory sync was started but not confirmed complete.
        case directorySyncAttempted = 5

        /// Directory synced, fully durable.
        case syncedDirectory = 6
    }
}

// MARK: - Properties

extension File.System.Write.Atomic.Commit.Phase {
    /// Returns true if file has been atomically published to destination.
    ///
    /// When this is true, the file exists with complete contents at the destination path.
    /// However, durability may not be guaranteed if `durabilityAttempted` is false.
    public var published: Bool { self.rawValue >= Self.renamedPublished.rawValue }

    /// Returns true if directory sync was attempted (for postmortem diagnostics).
    ///
    /// Distinguishes "sync started but failed/cancelled" from "sync never attempted".
    public var durabilityAttempted: Bool { self.rawValue >= Self.directorySyncAttempted.rawValue }
}

// MARK: - Comparable

extension File.System.Write.Atomic.Commit.Phase: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.Commit.swift
// ============================================================

//
//  File.System.Write.Atomic.Commit.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    /// Namespace for commit-related types.
    public enum Commit {
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.Durability.swift
// ============================================================

//
//  File.System.Write.Atomic.Durability.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Write.Atomic {
    /// Controls the durability guarantees for file synchronization.
    ///
    /// Higher durability modes provide stronger crash-safety but slower performance.
    public enum Durability: Sendable {
        /// Full synchronization with F_FULLFSYNC on macOS (default).
        ///
        /// Guarantees data is written to physical storage and survives power loss.
        /// Slowest but safest option.
        case full

        /// Data-only synchronization without metadata sync where available.
        ///
        /// Uses fdatasync() on Linux or F_BARRIERFSYNC on macOS if available.
        /// Faster than `.full` but still durable for most use cases.
        /// Falls back to fsync if platform-specific optimizations unavailable.
        case dataOnly

        /// No synchronization - data may be buffered in OS caches.
        ///
        /// Fastest option but provides no crash-safety guarantees.
        /// Suitable for caches, temporary files, or build artifacts.
        case none
    }
}

// MARK: - RawRepresentable

extension File.System.Write.Atomic.Durability: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .full: return 0
        case .dataOnly: return 1
        case .none: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .full
        case 1: self = .dataOnly
        case 2: self = .none
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic.Durability: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.Error.swift
// ============================================================

//
//  File.System.Write.Atomic.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parent(File.System.Parent.Check.Error)
        case destinationStatFailed(path: File.Path, code: File.System.Error.Code, message: String)
        case tempFileCreationFailed(directory: File.Path, code: File.System.Error.Code, message: String)
        case writeFailed(bytesWritten: Int, bytesExpected: Int, code: File.System.Error.Code, message: String)
        case syncFailed(code: File.System.Error.Code, message: String)
        case closeFailed(code: File.System.Error.Code, message: String)
        case metadataPreservationFailed(operation: String, code: File.System.Error.Code, message: String)
        case renameFailed(from: File.Path, to: File.Path, code: File.System.Error.Code, message: String)
        case destinationExists(path: File.Path)
        case directorySyncFailed(path: File.Path, code: File.System.Error.Code, message: String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation. The caller should NOT attempt
        /// to "finish durability" - this is not reliably possible.
        case directorySyncFailedAfterCommit(path: File.Path, code: File.System.Error.Code, message: String)

        /// CSPRNG failed - cannot generate secure temp file names.
        ///
        /// This indicates a fundamental system failure (e.g., getrandom syscall failure).
        /// The operation cannot proceed safely without secure random bytes.
        case randomGenerationFailed(code: File.System.Error.Code, operation: String, message: String)

        /// Platform layout incompatibility at runtime.
        ///
        /// This occurs when platform-specific struct layouts don't match expectations.
        /// Typically indicates a need for fallback to alternative APIs.
        case platformIncompatible(operation: String, message: String)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Atomic.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parent(let error):
            return "Parent directory error: \(error)"
        case .destinationStatFailed(let path, let code, let message):
            return "Failed to stat destination '\(path)': \(message) (\(code))"
        case .tempFileCreationFailed(let directory, let code, let message):
            return "Failed to create temp file in '\(directory)': \(message) (\(code))"
        case .writeFailed(let written, let expected, let code, let message):
            return "Write failed after \(written)/\(expected) bytes: \(message) (\(code))"
        case .syncFailed(let code, let message):
            return "Sync failed: \(message) (\(code))"
        case .closeFailed(let code, let message):
            return "Close failed: \(message) (\(code))"
        case .metadataPreservationFailed(let op, let code, let message):
            return "Metadata preservation failed (\(op)): \(message) (\(code))"
        case .renameFailed(let from, let to, let code, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (\(code))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let code, let message):
            return "Directory sync failed '\(path)': \(message) (\(code))"
        case .directorySyncFailedAfterCommit(let path, let code, let message):
            return "Directory sync failed after commit '\(path)': \(message) (\(code))"
        case .randomGenerationFailed(let code, let operation, let message):
            return "Random generation failed (\(operation)): \(message) (\(code))"
        case .platformIncompatible(let operation, let message):
            return "Platform incompatible (\(operation)): \(message)"
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.Options.swift
// ============================================================

//
//  File.System.Write.Atomic.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    /// Options controlling atomic write behavior.
    public struct Options: Sendable {
        public var strategy: Strategy
        public var durability: Durability
        public var preservePermissions: Bool
        public var preserveOwnership: Bool
        public var strictOwnership: Bool
        public var preserveTimestamps: Bool
        public var preserveExtendedAttributes: Bool
        public var preserveACLs: Bool
        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            strategy: Strategy = .replaceExisting,
            durability: Durability = .full,
            preservePermissions: Bool = true,
            preserveOwnership: Bool = false,
            strictOwnership: Bool = false,
            preserveTimestamps: Bool = false,
            preserveExtendedAttributes: Bool = false,
            preserveACLs: Bool = false,
            createIntermediates: Bool = false
        ) {
            self.strategy = strategy
            self.durability = durability
            self.preservePermissions = preservePermissions
            self.preserveOwnership = preserveOwnership
            self.strictOwnership = strictOwnership
            self.preserveTimestamps = preserveTimestamps
            self.preserveExtendedAttributes = preserveExtendedAttributes
            self.preserveACLs = preserveACLs
            self.createIntermediates = createIntermediates
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.Strategy.swift
// ============================================================

//
//  File.System.Write.Atomic.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Write.Atomic {
    /// Controls behavior when the destination file already exists.
    public enum Strategy: Sendable {
        /// Replace the existing file atomically (default).
        case replaceExisting

        /// Fail if the destination already exists.
        case noClobber
    }
}

// MARK: - RawRepresentable

extension File.System.Write.Atomic.Strategy: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .replaceExisting: return 0
        case .noClobber: return 1
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .replaceExisting
        case 1: self = .noClobber
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic.Strategy: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.System.Write.Atomic.swift
// ============================================================

// File.System.Write.Atomic.swift
// Atomic file writing with crash-safety guarantees
//
// This module provides atomic file writes using the standard pattern:
//   1. Write to a temporary file in the same directory
//   2. Sync the file to disk (fsync)
//   3. Atomically rename temp → destination (rename is atomic on POSIX/NTFS)
//   4. Sync the directory to ensure the rename is persisted
//
// This guarantees that on any crash or power failure, you either have:
//   - The complete new file, or
//   - The complete old file (or no file if it didn't exist)
// You never get a partial/corrupted file.
//
// ## Security Considerations
//
// ### Symlink/Reparse-Point Handling
// This library does NOT provide hardened path resolution against symlink attacks.
// The O_NOFOLLOW flag (when used) only protects the final path component.
//
// **Threat model:**
// - Safe for: Writing to directories YOU control (application data, caches)
// - NOT safe for: Writing to attacker-controlled paths (e.g., /tmp with user input)
//
// Intermediate path components can still be symlinks, enabling TOCTOU attacks
// where an attacker replaces a directory with a symlink between path validation
// and file creation.
//
// For security-critical use cases in adversarial environments, consider:
// 1. Using openat() with O_NOFOLLOW at each path component
// 2. Validating the entire path is within expected bounds before writing
// 3. Using OS-provided secure temp directory APIs
// 4. Avoiding user-controlled path components entirely

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Write {
    /// Atomic file writing with crash-safety guarantees.
    public enum Atomic {
    }
}

// MARK: - Core API

extension File.System.Write.Atomic {
    /// Atomically writes bytes to a file path.
    ///
    /// This is the core primitive - all other write operations compose on top of this.
    ///
    /// ## Guarantees
    /// - Either the file exists with complete contents, or the original state is preserved
    /// - On success, data is synced to physical storage (survives power loss)
    /// - Safe to call concurrently for different paths
    ///
    /// ## Requirements
    /// - Parent directory must exist and be writable
    ///
    /// - Parameters:
    ///   - bytes: The data to write (borrowed, zero-copy)
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write(
        _ bytes: borrowing Span<UInt8>,
        to path: File.Path,
        options: borrowing Options = Options()
    ) throws(Error) {
        #if os(Windows)
            try WindowsAtomic.writeSpan(bytes, to: path.string, options: options)
        #else
            try POSIXAtomic.writeSpan(bytes, to: path.string, options: options)
        #endif
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic {
    /// Atomically writes a Binary.Serializable value to a file path.
    ///
    /// Uses `withSerializedBytes` for zero-copy access when the type supports it.
    ///
    /// - Parameters:
    ///   - value: The serializable value to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write<S: Binary.Serializable>(
        _ value: S,
        to path: File.Path,
        options: Options = Options()
    ) throws(Error) {
        try S.withSerializedBytes(value) { (span: borrowing Span<UInt8>) throws(Error) in
            try write(span, to: path, options: options)
        }
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Atomic {
    /// Returns a human-readable error message for a system error code.
    @usableFromInline
    static func errorMessage(for code: File.System.Error.Code) -> String {
        code.message
    }

    /// Legacy helper for migration - converts errno to ErrorCode.
    @usableFromInline
    static func errorMessage(for errno: Int32) -> String {
        #if os(Windows)
            return "error \(errno)"
        #else
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            return "error \(errno)"
        #endif
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming+POSIX.swift
// ============================================================

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

    public enum POSIXStreaming {

        // MARK: - Generic Sequence API

        static func write<Chunks: Sequence>(
            _ chunks: Chunks,
            to path: borrowing String,
            options: borrowing File.System.Write.Streaming.Options
        ) throws(File.System.Write.Streaming.Error)
        where Chunks.Element == [UInt8] {

            let resolvedPath = resolvePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

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

            // Write all chunks - internally convert to Span for zero-copy writes
            for chunk in chunks {
                try chunk.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try writeAll(span, to: fd, path: resolvedPath)
                }
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

            // Write all chunks - internally convert to Span for zero-copy writes
            for chunk in chunks {
                try chunk.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try writeAll(span, to: fd, path: resolvedPath)
                }
            }

            try syncFile(fd, durability: options.durability)
            try closeFile(fd)
            didClose = true
        }
    }

    // MARK: - Path Handling

    extension POSIXStreaming {

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

    extension POSIXStreaming {

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

            let fd = path.withCString { open($0, flags, mode) }

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
                            message: "renameat2 returned EPERM, fallback also failed: \(fallbackError)"
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

            let fd = path.withCString { open($0, flags) }

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

    extension POSIXStreaming {

        /// Namespace for write-related types.
        public enum Write {
        }
    }

    extension POSIXStreaming.Write {
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

    extension POSIXStreaming {
        /// Opens a file for multi-phase streaming write.
        ///
        /// Returns a context that can be used for subsequent writeChunk and commit calls.
        public static func openForStreaming(
            path: String,
            options: File.System.Write.Streaming.Options
        ) throws(File.System.Write.Streaming.Error) -> Write.Context {

            let resolvedPath = resolvePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

            switch options.commit {
            case .atomic(let atomicOptions):
                let tempPath = generateTempPath(in: parent, for: resolvedPath)
                let fd = try createFile(at: tempPath, exclusive: true)
                return Write.Context(
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
                let fd = try createFile(at: resolvedPath, exclusive: directOptions.strategy == .create)
                return Write.Context(
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
        public static func writeChunk(
            _ span: borrowing Span<UInt8>,
            to context: borrowing Write.Context
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
            _ context: borrowing Write.Context
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
        public static func cleanup(_ context: borrowing Write.Context) {
            // Close fd if still open (ignore errors)
            _ = close(context.fd)

            // Remove temp file if atomic mode
            if let tempPath = context.tempPath {
                _ = tempPath.withCString { unlink($0) }
            }
        }
    }

#endif  // !os(Windows)

// ============================================================
// MARK: - File.System.Write.Streaming+Windows.swift
// ============================================================

// File.System.Write.Streaming+Windows.swift
// Windows implementation of streaming file writes

#if os(Windows)

    import WinSDK
    import INCITS_4_1986

    // MARK: - Windows Implementation

    public enum WindowsStreaming {

        // MARK: - Generic Sequence API

        static func write<Chunks: Sequence>(
            _ chunks: Chunks,
            to path: borrowing String,
            options: borrowing File.System.Write.Streaming.Options
        ) throws(File.System.Write.Streaming.Error)
        where Chunks.Element == [UInt8] {

            let resolvedPath = normalizePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

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

            // noClobber semantics are enforced by MoveFileExW without
            // MOVEFILE_REPLACE_EXISTING. We do NOT pre-check existence here
            // because that would be semantically wrong: noClobber means "don't
            // overwrite if file exists at publish time", not "fail if file exists
            // at start time". A pre-check could cause incorrect early failure if
            // the file is removed between check and publish.

            let tempPath = generateTempPath(in: parent, for: resolvedPath)
            let handle = try createFile(at: tempPath, exclusive: true)

            var handleClosed = false
            var renamed = false

            defer {
                if !handleClosed { _ = CloseHandle(handle) }
                if !renamed { _ = deleteFile(tempPath) }
            }

            // Write all chunks - internally convert to Span for zero-copy writes
            for chunk in chunks {
                try chunk.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try writeAll(span, to: handle, path: resolvedPath)
                }
            }

            try flushFile(handle, durability: options.durability)

            guard _ok(CloseHandle(handle)) else {
                throw .closeFailed(
                    errno: Int32(GetLastError()),
                    message: "CloseHandle failed"
                )
            }
            handleClosed = true

            // Use appropriate rename based on strategy
            switch options.strategy {
            case .replaceExisting:
                try atomicRename(from: tempPath, to: resolvedPath)
            case .noClobber:
                try atomicRenameNoClobber(from: tempPath, to: resolvedPath)
            }
            renamed = true

            // Directory sync after publish - only for .full durability.
            // Directory sync is a metadata persistence step, so it should NOT be
            // performed for .dataOnly (which explicitly states "metadata may not
            // be persisted").
            if options.durability == .full {
                do {
                    try flushDirectory(parent)
                } catch let syncError {
                    // Extract errno from the sync error for the after-commit error
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

            let handle = try createFile(at: resolvedPath, exclusive: options.strategy == .create)

            var handleClosed = false

            defer {
                if !handleClosed { _ = CloseHandle(handle) }
            }

            // Write all chunks - internally convert to Span for zero-copy writes
            for chunk in chunks {
                try chunk.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try writeAll(span, to: handle, path: resolvedPath)
                }
            }

            try flushFile(handle, durability: options.durability)

            guard _ok(CloseHandle(handle)) else {
                throw .closeFailed(
                    errno: Int32(GetLastError()),
                    message: "CloseHandle failed"
                )
            }
            handleClosed = true
        }
    }

    // MARK: - Path Handling

    extension WindowsStreaming {

        private static func normalizePath(_ path: String) -> String {
            var result = ""
            result.reserveCapacity(path.utf8.count)
            for char in path {
                if char == "/" {
                    result.append("\\")
                } else {
                    result.append(char)
                }
            }

            while result.count > 3 && result.hasSuffix("\\") {
                result.removeLast()
            }

            return result
        }

        private static func parentDirectory(of path: String) -> String {
            if let lastSep = path.lastIndex(of: "\\") {
                if lastSep == path.startIndex {
                    return String(path[...lastSep])
                }
                let prefix = String(path[..<lastSep])
                if prefix.count == 2 && prefix.last == ":" {
                    return prefix + "\\"
                }
                return prefix
            }
            return "."
        }

        private static func fileName(of path: String) -> String {
            if let lastSep = path.lastIndex(of: "\\") {
                return String(path[path.index(after: lastSep)...])
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
            let attrs = withWideString(path) { GetFileAttributesW($0) }
            return attrs != INVALID_FILE_ATTRIBUTES
        }

        private static func generateTempPath(in parent: String, for destPath: String) -> String {
            let baseName = fileName(of: destPath)
            let random = randomHex(12)
            return "\(parent)\\\(baseName).streaming.\(random).tmp"
        }

        private nonisolated(unsafe) static var _counter: UInt32 = 0

        private static func randomHex(_ byteCount: Int) -> String {
            let pid = GetCurrentProcessId()
            let tick = GetTickCount64()
            _counter &+= 1

            let digit0 = UInt32(UInt8.ascii.`0`)
            let letterA = UInt32(UInt8.ascii.a)

            var result = ""
            let value = UInt64(pid) ^ tick ^ UInt64(_counter)
            var remaining = value
            for _ in 0..<min(byteCount * 2, 16) {
                let nibble = UInt32(remaining & 0xF)
                let code = nibble < 10 ? (digit0 + nibble) : (letterA - 10 + nibble)
                result.append(Character(Unicode.Scalar(code)!))
                remaining >>= 4
            }
            return result
        }
    }

    // MARK: - File Operations

    extension WindowsStreaming {

        private static func createFile(
            at path: String,
            exclusive: Bool
        ) throws(File.System.Write.Streaming.Error) -> HANDLE {
            let disposition: DWORD = exclusive ? _dword(CREATE_NEW) : _dword(CREATE_ALWAYS)

            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _dword(GENERIC_WRITE),
                    0,
                    nil,
                    disposition,
                    _mask(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                let err = GetLastError()
                throw .fileCreationFailed(
                    path: File.Path(__unchecked: (), path),
                    errno: Int32(err),
                    message: "CreateFileW failed with error \(err)"
                )
            }

            return handle
        }

        /// Writes all bytes to handle, handling partial writes.
        private static func writeAll(
            _ span: borrowing Span<UInt8>,
            to handle: HANDLE,
            path: String
        ) throws(File.System.Write.Streaming.Error) {
            let total = span.count
            if total == 0 { return }

            var written = 0

            try span.withUnsafeBufferPointer { buffer throws(File.System.Write.Streaming.Error) in
                guard let base = buffer.baseAddress else { return }

                while written < total {
                    let remaining = total - written
                    var bytesWritten: DWORD = 0

                    let success = WriteFile(
                        handle,
                        UnsafeRawPointer(base.advanced(by: written)),
                        DWORD(truncatingIfNeeded: remaining),
                        &bytesWritten,
                        nil
                    )

                    if !_ok(success) {
                        let err = GetLastError()
                        throw File.System.Write.Streaming.Error.writeFailed(
                            path: File.Path(__unchecked: (), path),
                            bytesWritten: written,
                            errno: Int32(err),
                            message: "WriteFile failed with error \(err)"
                        )
                    }

                    if bytesWritten == 0 {
                        throw File.System.Write.Streaming.Error.writeFailed(
                            path: File.Path(__unchecked: (), path),
                            bytesWritten: written,
                            errno: 0,
                            message: "WriteFile wrote 0 bytes"
                        )
                    }

                    written += Int(bytesWritten)
                }
            }
        }

        private static func flushFile(
            _ handle: HANDLE,
            durability: File.System.Write.Streaming.Durability
        ) throws(File.System.Write.Streaming.Error) {
            switch durability {
            case .full, .dataOnly:
                if !_ok(FlushFileBuffers(handle)) {
                    let err = GetLastError()
                    throw .syncFailed(
                        errno: Int32(err),
                        message: "FlushFileBuffers failed with error \(err)"
                    )
                }
            case .none:
                break
            }
        }

        private static func deleteFile(_ path: String) -> Bool {
            return withWideString(path) { DeleteFileW($0) }
        }

        private static func atomicRename(
            from tempPath: String,
            to destPath: String
        ) throws(File.System.Write.Streaming.Error) {
            let flags: DWORD = _dword(MOVEFILE_REPLACE_EXISTING) | _dword(MOVEFILE_WRITE_THROUGH)

            let success = withWideString(tempPath) { wTemp in
                withWideString(destPath) { wDest in
                    MoveFileExW(wTemp, wDest, flags)
                }
            }

            if !success {
                let err = GetLastError()
                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    errno: Int32(err),
                    message: "MoveFileExW failed with error \(err)"
                )
            }
        }

        /// Atomically renames temp file to destination, failing if destination exists.
        ///
        /// Uses MoveFileExW without MOVEFILE_REPLACE_EXISTING - the rename will
        /// fail with ERROR_ALREADY_EXISTS or ERROR_FILE_EXISTS if destination exists.
        private static func atomicRenameNoClobber(
            from tempPath: String,
            to destPath: String
        ) throws(File.System.Write.Streaming.Error) {
            // Only use MOVEFILE_WRITE_THROUGH, NOT MOVEFILE_REPLACE_EXISTING
            let flags: DWORD = _dword(MOVEFILE_WRITE_THROUGH)

            let success = withWideString(tempPath) { wTemp in
                withWideString(destPath) { wDest in
                    MoveFileExW(wTemp, wDest, flags)
                }
            }

            if !success {
                let err = GetLastError()
                // Multiple error codes can indicate "exists":
                // - ERROR_ALREADY_EXISTS (183)
                // - ERROR_FILE_EXISTS (80)
                // Note: ERROR_ACCESS_DENIED can occur for various reasons,
                // so we don't map it to destinationExists to avoid masking real permission errors
                if err == _dword(ERROR_ALREADY_EXISTS) || err == _dword(ERROR_FILE_EXISTS) {
                    throw .destinationExists(path: File.Path(__unchecked: (), destPath))
                }
                throw .renameFailed(
                    from: File.Path(__unchecked: (), tempPath),
                    to: File.Path(__unchecked: (), destPath),
                    errno: Int32(err),
                    message: "MoveFileExW failed with error \(err)"
                )
            }
        }

        private static func flushDirectory(_ path: String) throws(File.System.Write.Streaming.Error) {
            let handle = withWideString(path) { wPath in
                CreateFileW(
                    wPath,
                    _dword(GENERIC_READ),
                    _mask(FILE_SHARE_READ) | _mask(FILE_SHARE_WRITE) | _mask(FILE_SHARE_DELETE),
                    nil,
                    _dword(OPEN_EXISTING),
                    _mask(FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }

            guard let handle = handle, handle != INVALID_HANDLE_VALUE else {
                let err = GetLastError()
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    errno: Int32(err),
                    message: "CreateFileW(directory) failed with error \(err)"
                )
            }
            defer { _ = CloseHandle(handle) }

            if !_ok(FlushFileBuffers(handle)) {
                let err = GetLastError()
                throw .directorySyncFailed(
                    path: File.Path(__unchecked: (), path),
                    errno: Int32(err),
                    message: "FlushFileBuffers(directory) failed with error \(err)"
                )
            }
        }
    }

    // MARK: - Utilities

    extension WindowsStreaming {

        private static func withWideString<T>(
            _ string: String,
            _ body: (UnsafePointer<WCHAR>) -> T
        ) -> T {
            string.withCString(encodedAs: UTF16.self) { utf16Ptr in
                utf16Ptr.withMemoryRebound(to: WCHAR.self, capacity: string.utf16.count + 1) {
                    wcharPtr in
                    body(wcharPtr)
                }
            }
        }
    }

    // MARK: - Multi-phase Streaming Helpers (for async)

    extension WindowsStreaming {

        /// Namespace for write-related types.
        public enum Write {
        }
    }

    extension WindowsStreaming.Write {
        /// Context for multi-phase streaming writes.
        ///
        /// @unchecked Sendable because all fields are immutable value types.
        /// HANDLE is a pointer but Windows file handles are thread-safe for sequential operations.
        /// Safe to pass to io.run closures within a single async function.
        public struct Context: @unchecked Sendable {
            public let handle: HANDLE
            public let tempPath: String?  // nil for direct mode
            public let resolvedPath: String
            public let parent: String
            public let durability: File.System.Write.Streaming.Durability
            public let isAtomic: Bool
            public let strategy: File.System.Write.Streaming.Atomic.Strategy?
        }
    }

    extension WindowsStreaming {
        /// Opens a file for multi-phase streaming write.
        ///
        /// Returns a context that can be used for subsequent writeChunk and commit calls.
        public static func openForStreaming(
            path: String,
            options: File.System.Write.Streaming.Options
        ) throws(File.System.Write.Streaming.Error) -> Write.Context {

            let resolvedPath = normalizePath(path)
            let parent = parentDirectory(of: resolvedPath)
            try verifyOrCreateParentDirectory(parent, createIntermediates: options.createIntermediates)

            switch options.commit {
            case .atomic(let atomicOptions):
                let tempPath = generateTempPath(in: parent, for: resolvedPath)
                let handle = try createFile(at: tempPath, exclusive: true)
                return Write.Context(
                    handle: handle,
                    tempPath: tempPath,
                    resolvedPath: resolvedPath,
                    parent: parent,
                    durability: atomicOptions.durability,
                    isAtomic: true,
                    strategy: atomicOptions.strategy
                )

            case .direct(let directOptions):
                let handle = try createFile(at: resolvedPath, exclusive: directOptions.strategy == .create)
                return Write.Context(
                    handle: handle,
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
        public static func writeChunk(
            _ span: borrowing Span<UInt8>,
            to context: borrowing Write.Context
        ) throws(File.System.Write.Streaming.Error) {
            try writeAll(span, to: context.handle, path: context.tempPath ?? context.resolvedPath)
        }

        /// Commits a streaming write, closing the file and performing the atomic rename if needed.
        ///
        /// This function owns post-publish error semantics:
        /// - Pre-publish failures throw normal errors
        /// - Post-publish I/O failures throw `.directorySyncFailedAfterCommit`
        public static func commit(
            _ context: borrowing Write.Context
        ) throws(File.System.Write.Streaming.Error) {

            // Sync file data
            try flushFile(context.handle, durability: context.durability)

            // Close the handle
            guard _ok(CloseHandle(context.handle)) else {
                throw .closeFailed(
                    errno: Int32(GetLastError()),
                    message: "CloseHandle failed"
                )
            }

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
                        try flushDirectory(context.parent)
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
        /// Best-effort cleanup - closes handle and removes temp file if atomic mode.
        public static func cleanup(_ context: borrowing Write.Context) {
            // Close handle if still open (ignore errors)
            _ = CloseHandle(context.handle)

            // Remove temp file if atomic mode
            if let tempPath = context.tempPath {
                _ = deleteFile(tempPath)
            }
        }
    }

#endif  // os(Windows)

// ============================================================
// MARK: - File.System.Write.Streaming.Atomic.Options.swift
// ============================================================

//
//  File.System.Write.Streaming.Atomic.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Atomic {
    /// Options for atomic streaming writes.
    ///
    /// Note: Unlike `File.System.Write.Atomic.Options`, streaming writes do not support
    /// metadata preservation. This is a simpler options type focused on
    /// durability and existence semantics.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Streaming.Durability

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Streaming.Durability = .full
        ) {
            self.strategy = strategy
            self.durability = durability
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Atomic.Strategy.swift
// ============================================================

//
//  File.System.Write.Streaming.Atomic.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Atomic {
    /// Strategy for atomic streaming writes.
    public enum Strategy: Sendable {
        /// Replace existing file (default).
        case replaceExisting

        /// Fail if destination already exists.
        ///
        /// Uses platform-specific atomic mechanisms:
        /// - macOS/iOS: `renamex_np` with `RENAME_EXCL`
        /// - Linux: `renameat2` with `RENAME_NOREPLACE`, fallback to `link+unlink`
        /// - Windows: `MoveFileExW` without `MOVEFILE_REPLACE_EXISTING`
        case noClobber
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Atomic.swift
// ============================================================

//
//  File.System.Write.Streaming.Atomic.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for atomic streaming write types.
    public enum Atomic {
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Commit.Policy.swift
// ============================================================

//
//  File.System.Write.Streaming.Commit.Policy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Commit {
    /// Controls how chunks are committed to disk.
    public enum Policy: Sendable {
        /// Atomic write via temp file + rename (crash-safe).
        ///
        /// - Write chunks to temp file in same directory
        /// - Sync temp file according to durability
        /// - Atomically rename to destination
        /// - Sync directory to persist rename
        ///
        /// Note: Unlike `File.System.Write.Atomic`, streaming does not support
        /// metadata preservation (timestamps, xattrs, ACLs, ownership).
        case atomic(File.System.Write.Streaming.Atomic.Options = .init())

        /// Direct write to destination (faster, no crash-safety).
        ///
        /// On crash or cancellation, file may be partially written.
        case direct(File.System.Write.Streaming.Direct.Options = .init())
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Commit.swift
// ============================================================

//
//  File.System.Write.Streaming.Commit.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for commit-related types.
    public enum Commit {
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Direct.Options.swift
// ============================================================

//
//  File.System.Write.Streaming.Direct.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Direct {
    /// Options for non-atomic (direct) writes.
    public struct Options: Sendable {
        /// Controls behavior when destination exists.
        public var strategy: Strategy

        /// Controls durability guarantees.
        public var durability: File.System.Write.Streaming.Durability

        /// Expected total size in bytes. When provided on macOS/iOS, enables
        /// preallocation via `fcntl(F_PREALLOCATE)` which can significantly
        /// improve write throughput for large files (up to 2x faster).
        ///
        /// ## Tradeoffs
        /// - **Pro**: Reduces APFS metadata updates during sequential writes
        /// - **Con**: Changes ENOSPC behavior - fails upfront if space unavailable
        /// - **Con**: Preallocates even if actual write is smaller
        ///
        /// Only used when total size is known upfront (e.g., bulk writes).
        /// Ignored for streaming writes where total size is unknown.
        public var expectedSize: Int64?

        public init(
            strategy: Strategy = .truncate,
            durability: File.System.Write.Streaming.Durability = .full,
            expectedSize: Int64? = nil
        ) {
            self.strategy = strategy
            self.durability = durability
            self.expectedSize = expectedSize
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Direct.Strategy.swift
// ============================================================

//
//  File.System.Write.Streaming.Direct.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Direct {
    /// Strategy for direct (non-atomic) writes.
    public enum Strategy: Sendable {
        /// Fail if destination exists.
        case create

        /// Truncate existing file or create new.
        case truncate
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Direct.swift
// ============================================================

//
//  File.System.Write.Streaming.Direct.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for direct streaming write types.
    public enum Direct {
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Durability.swift
// ============================================================

//
//  File.System.Write.Streaming.Durability.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Controls durability guarantees for streaming writes.
    public enum Durability: Sendable {
        /// Full durability - both data and metadata synced.
        /// Uses `F_FULLFSYNC` on Darwin, `fsync` elsewhere.
        case full

        /// Data-only sync - metadata may not be persisted.
        /// Uses `F_BARRIERFSYNC` on Darwin, `fdatasync` on Linux.
        case dataOnly

        /// No sync - rely on OS buffers.
        /// Faster but data may be lost on power failure.
        case none
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Error.swift
// ============================================================

//
//  File.System.Write.Streaming.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parent(File.System.Parent.Check.Error)
        case fileCreationFailed(path: File.Path, errno: Int32, message: String)
        /// Write operation failed.
        case writeFailed(path: File.Path, bytesWritten: Int, errno: Int32, message: String)
        case syncFailed(errno: Int32, message: String)
        case closeFailed(errno: Int32, message: String)
        case renameFailed(from: File.Path, to: File.Path, errno: Int32, message: String)
        case destinationExists(path: File.Path)
        case directorySyncFailed(path: File.Path, errno: Int32, message: String)

        /// Write completed but durability guarantee not met due to cancellation.
        ///
        /// File data was flushed (fsync succeeded), but directory entry may not be persisted.
        /// The destination path exists and contains complete content.
        ///
        /// **Callers should NOT attempt to "finish durability"** - this is not reliably possible.
        case durabilityNotGuaranteed(path: File.Path, reason: String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation.
        case directorySyncFailedAfterCommit(path: File.Path, errno: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Streaming.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parent(let error):
            return "Parent directory error: \(error)"
        case .fileCreationFailed(let path, let errno, let message):
            return "Failed to create file '\(path)': \(message) (errno=\(errno))"
        case .writeFailed(let path, let written, let errno, let message):
            return "Write failed to '\(path)' after \(written) bytes: \(message) (errno=\(errno))"
        case .syncFailed(let errno, let message):
            return "Sync failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .renameFailed(let from, let to, let errno, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (errno=\(errno))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let errno, let message):
            return "Directory sync failed '\(path)': \(message) (errno=\(errno))"
        case .durabilityNotGuaranteed(let path, let reason):
            return "Write to '\(path)' completed but durability not guaranteed: \(reason)"
        case .directorySyncFailedAfterCommit(let path, let errno, let message):
            return "Directory sync failed after commit '\(path)': \(message) (errno=\(errno))"
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.Options.swift
// ============================================================

//
//  File.System.Write.Streaming.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Options controlling streaming write behavior.
    public struct Options: Sendable {
        /// How to commit chunks to disk.
        public var commit: Commit.Policy
        /// Create intermediate directories if they don't exist.
        ///
        /// When enabled, missing parent directories are created before writing.
        /// Note: Creating intermediates may traverse symlinks in path components.
        /// This is not hardened against symlink-based attacks.
        public var createIntermediates: Bool

        public init(
            commit: Commit.Policy = .atomic(.init()),
            createIntermediates: Bool = false
        ) {
            self.commit = commit
            self.createIntermediates = createIntermediates
        }
    }
}

// ============================================================
// MARK: - File.System.Write.Streaming.swift
// ============================================================

// File.System.Write.Streaming.swift
// Streaming/chunked file writing with optional atomic guarantees
//
// This module provides memory-efficient file writes by processing data in chunks.
// When atomic mode is enabled (default), it uses the same temp-file pattern as
// File.System.Write.Atomic to ensure crash-safety.

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Write {
    /// Streaming/chunked file writing with optional atomic guarantees.
    ///
    /// Memory-efficient for large files - only holds one chunk at a time.
    ///
    /// ## Usage
    /// ```swift
    /// // Atomic streaming write (crash-safe, default)
    /// try File.System.Write.Streaming.write(chunks, to: path)
    ///
    /// // Direct streaming write (faster, no crash-safety)
    /// try File.System.Write.Streaming.write(chunks, to: path, options: .init(commit: .direct()))
    /// ```
    ///
    /// ## Performance Note
    /// For optimal performance, provide chunks of 64KB–1MB. Smaller chunks work
    /// correctly but with higher overhead due to syscall frequency.
    ///
    /// ## Windows Note
    ///
    /// Streaming writes deny all file sharing during the write operation.
    /// This is the safest default for data integrity but may cause:
    /// - Antivirus scanner interference (`ERROR_ACCESS_DENIED`)
    /// - File indexer conflicts
    /// - Inability to read file while writing
    ///
    /// If concurrent read access is required during writes, a different API
    /// with explicit share mode control would be needed.
    public enum Streaming {
    }
}

// MARK: - Core API

extension File.System.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    /// Internally converts each chunk to Span for zero-copy writes.
    ///
    /// ## Atomic Mode (default)
    /// - Writes to a temporary file in the same directory
    /// - Syncs temp file according to durability setting
    /// - Atomically renames on completion
    /// - Syncs directory to persist the rename
    /// - Either complete new file or original state preserved on crash
    ///
    /// ## Direct Mode
    /// - Writes directly to destination
    /// - Faster but partial writes possible on crash
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write<Chunks: Sequence>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options = Options()
    ) throws(Error) where Chunks.Element == [UInt8] {
        #if os(Windows)
            try WindowsStreaming.write(chunks, to: path.string, options: options)
        #else
            try POSIXStreaming.write(chunks, to: path.string, options: options)
        #endif
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Streaming {
    @usableFromInline
    static func errorMessage(for errno: Int32) -> String {
        #if os(Windows)
            return "error \(errno)"
        #else
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            return "error \(errno)"
        #endif
    }
}

// ============================================================
// MARK: - File.System.Write.swift
// ============================================================

//
//  File.System.Write.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    public enum Write {}
}

// ============================================================
// MARK: - File.System.swift
// ============================================================

//
//  File.System.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File {
    /// Namespace for file system operations.
    public enum System {

    }
}

// MARK: - Error Namespace

extension File.System {
    /// Namespace for error-related types.
    public enum Error {

    }
}

// ============================================================
// MARK: - File.Watcher.swift
// ============================================================

//
//  File.Watcher.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File {
    /// File system event watching (future implementation).
    public enum Watcher {
        // TODO: Implementation using FSEvents/inotify
    }
}

extension File.Watcher {
    /// A file system event.
    public struct Event: Sendable {
        /// The path that changed.
        public let path: File.Path

        /// The type of event.
        public let type: EventType

        public init(path: File.Path, type: EventType) {
            self.path = path
            self.type = type
        }
    }

    /// The type of file system event.
    public enum EventType: Sendable {
        case created
        case modified
        case deleted
        case renamed
        case attributesChanged
    }

    /// Options for file watching.
    public struct Options: Sendable {
        /// Whether to watch subdirectories recursively.
        public var recursive: Bool

        /// Latency in seconds before coalescing events.
        public var latency: Double

        public init(
            recursive: Bool = false,
            latency: Double = 0.5
        ) {
            self.recursive = recursive
            self.latency = latency
        }
    }
}

// MARK: - RawRepresentable

extension File.Watcher.EventType: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .created: return 0
        case .modified: return 1
        case .deleted: return 2
        case .renamed: return 3
        case .attributesChanged: return 4
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .created
        case 1: self = .modified
        case 2: self = .deleted
        case 3: self = .renamed
        case 4: self = .attributesChanged
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Watcher.EventType: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// ============================================================
// MARK: - File.swift
// ============================================================

//
//  File.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

/// A file reference providing convenient access to filesystem operations.
///
/// `File` wraps a path and provides ergonomic methods that
/// delegate to `File.System.*` primitives. It is Hashable and Sendable.
///
/// ## Modern Swift Features
/// - ExpressibleByStringLiteral for ergonomic initialization
/// - Async variants for concurrent contexts
/// - Throwing getters for metadata properties
///
/// ## Example
/// ```swift
/// let file: File = "/tmp/data.txt"
/// let contents = try file.read()
/// try file.write("Hello!")
///
/// // Property-style stat checks
/// if file.exists && file.isFile {
///     print("Size: \(try file.size)")
/// }
/// ```
public struct File: Hashable, Sendable {
    /// The underlying file path.
    public let path: File.Path

    // MARK: - Initializers

    /// Creates a file from a path.
    ///
    /// - Parameter path: The file path.
    public init(_ path: File.Path) {
        self.path = path
    }
}

// ============================================================
// MARK: - String+DirectoryEntryName.swift
// ============================================================

//
//  String+DirectoryEntryName.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
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

// MARK: - POSIX d_name

#if !os(Windows)
    extension String {
        /// Creates a string from a POSIX directory entry name (d_name).
        ///
        /// The `d_name` field in `dirent` is a fixed-size C character array.
        /// This initializer safely extracts the name using bounded access.
        ///
        /// ## Memory Safety
        /// Uses `MemoryLayout.size(ofValue:)` to determine actual buffer size,
        /// then finds the NUL terminator within that bound. Never reads past
        /// the buffer.
        ///
        /// ## Encoding Policy
        /// Uses lossy UTF-8 decoding. Invalid UTF-8 sequences are replaced with
        /// the Unicode replacement character (U+FFFD). This means path round-tripping
        /// is not guaranteed for filenames containing invalid UTF-8.
        @usableFromInline
        internal init<T>(posixDirectoryEntryName dName: T) {
            self = withUnsafePointer(to: dName) { ptr in
                // Get actual buffer size from the type, not NAME_MAX
                let bufferSize = MemoryLayout<T>.size

                return ptr.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bytes in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < bufferSize && bytes[length] != 0 {
                        length += 1
                    }

                    // Create buffer view up to NUL (or end of buffer)
                    let buffer = UnsafeBufferPointer(start: bytes, count: length)

                    // Lossy UTF-8 decode - invalid sequences become U+FFFD
                    return String(decoding: buffer, as: UTF8.self)
                }
            }
        }
    }
#endif

// MARK: - Windows cFileName

#if os(Windows)
    extension String {
        /// Creates a string from a Windows directory entry name (cFileName).
        ///
        /// The `cFileName` field in `WIN32_FIND_DATAW` is a fixed-size wide character array.
        /// This initializer safely extracts the name using bounded access.
        ///
        /// ## Memory Safety
        /// Uses `MemoryLayout.size(ofValue:)` to determine actual buffer size,
        /// then finds the NUL terminator within that bound. Never reads past
        /// the buffer.
        ///
        /// ## Encoding Policy
        /// Uses lossy UTF-16 decoding. Invalid UTF-16 sequences (e.g., lone surrogates)
        /// are replaced with the Unicode replacement character (U+FFFD). This means
        /// path round-tripping is not guaranteed for filenames containing invalid UTF-16.
        @usableFromInline
        internal init<T>(windowsDirectoryEntryName cFileName: T) {
            self = withUnsafePointer(to: cFileName) { ptr in
                // Get actual buffer size from the type, not MAX_PATH
                let bufferSize = MemoryLayout<T>.size
                let elementCount = bufferSize / MemoryLayout<UInt16>.size

                return ptr.withMemoryRebound(to: UInt16.self, capacity: elementCount) { wchars in
                    // Find NUL terminator within bounds
                    var length = 0
                    while length < elementCount && wchars[length] != 0 {
                        length += 1
                    }

                    // Create buffer view up to NUL (or end of buffer)
                    let buffer = UnsafeBufferPointer(start: wchars, count: length)

                    // Lossy UTF-16 decode - invalid sequences become U+FFFD
                    return String(decoding: buffer, as: UTF16.self)
                }
            }
        }
    }
#endif

// ============================================================
// MARK: - WinSDK+Helpers.swift
// ============================================================

//
//  WinSDK+Helpers.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 19/12/2025.
//

#if os(Windows)
    import WinSDK

    // MARK: - DWORD Conversion Helpers

    // Note: On Windows, DWORD is a typealias for UInt32, so we only need one overload.
    // The Int32 overload handles constants that may be typed as signed integers.

    /// Converts a UInt32/DWORD value to DWORD.
    @inline(__always)
    internal func _dword(_ value: UInt32) -> DWORD { value }

    /// Converts an Int32 value to DWORD using bit-preserving conversion.
    @inline(__always)
    internal func _dword(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

    // MARK: - Mask Helpers for Bitwise Operations

    /// Converts a UInt32/DWORD value to DWORD for mask operations.
    @inline(__always)
    internal func _mask(_ value: UInt32) -> DWORD { value }

    /// Converts an Int32 value to DWORD for mask operations using bit-preserving conversion.
    @inline(__always)
    internal func _mask(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

    // MARK: - Boolean Adapters

    // In Swift 6.2, the WinSDK overlay has converted most Windows APIs to return Swift Bool.
    // However, some APIs still return BOOLEAN (UInt8) or WindowsBool.

    /// Identity adapter for Windows API return values that return Bool.
    @inline(__always)
    internal func _ok(_ value: Bool) -> Bool { value }

    /// Adapter for Windows APIs that return BOOLEAN (UInt8).
    /// Some APIs like CreateSymbolicLinkW still return BOOLEAN.
    @inline(__always)
    internal func _ok(_ value: BOOLEAN) -> Bool { value != 0 }

#endif

// ============================================================
// MARK: - exports.swift
// ============================================================

// exports.swift
// File System module exports

@_exported public import Binary
@_exported public import INCITS_4_1986
@_exported public import RFC_4648
@_exported public import SystemPackage
