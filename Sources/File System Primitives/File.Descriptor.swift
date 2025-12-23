//
//  File.Descriptor.swift
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
            internal var _handle: File.Unsafe.Sendable<HANDLE?>
        #else
            @usableFromInline
            internal var _fd: Int32
        #endif

        #if os(Windows)
            /// Creates a descriptor from a raw Windows HANDLE.
            @usableFromInline
            internal init(__unchecked handle: HANDLE) {
                self._handle = File.Unsafe.Sendable(handle)
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
    ) throws(File.Descriptor.Error) -> File.Descriptor {
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
    public consuming func close() throws(File.Descriptor.Error) {
        #if os(Windows)
            guard let handle = _handle.value, handle != INVALID_HANDLE_VALUE else {
                throw .alreadyClosed
            }
            // Invalidate first - handle is consumed regardless of CloseHandle result
            // This prevents double-close via deinit if CloseHandle fails
            let handleToClose = handle
            _handle = File.Unsafe.Sendable(INVALID_HANDLE_VALUE)
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
    public init(duplicating other: borrowing File.Descriptor) throws(File.Descriptor.Error) {
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
