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
    internal import WinSDK
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
    /// var handle = try File.Handle.open(path, mode: [.read, .write])
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
    ) throws(File.Handle.Error) -> File.Handle {
        var descriptorMode: File.Descriptor.Mode = []
        var descriptorOptions: File.Descriptor.Options = []

        // Map Handle.Mode to Descriptor.Mode
        if mode.contains(.read) {
            descriptorMode.insert(.read)
        }
        if mode.contains(.write) || mode.contains(.append) {
            descriptorMode.insert(.write)
        }
        if mode.contains(.append) {
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
    public mutating func read(count: Int) throws(File.Handle.Error) -> [UInt8] {
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
    public mutating func read(
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(File.Handle.Error) -> Int {
        guard _descriptor.isValid else { throw .invalidHandle }
        guard !buffer.isEmpty else { return 0 }

        #if os(Windows)
            guard let handle = _descriptor.rawHandle else {
                throw .invalidHandle
            }
            var bytesRead: DWORD = 0
            guard
                _ok(
                    ReadFile(
                        handle,
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
    public mutating func write(_ bytes: borrowing Span<UInt8>) throws(File.Handle.Error) {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        let count = bytes.count
        if count == 0 { return }

        try bytes.withUnsafeBufferPointer { buffer throws(File.Handle.Error) in
            guard let base = buffer.baseAddress else { return }

            #if os(Windows)
                guard let handle = _descriptor.rawHandle else {
                    throw .invalidHandle
                }
                // Loop for partial writes - WriteFile may return fewer bytes than requested
                var totalWritten: Int = 0
                while totalWritten < count {
                    var written: DWORD = 0
                    let remaining = count - totalWritten
                    let ptr = base.advanced(by: totalWritten)
                    let success = _ok(
                        WriteFile(
                            handle,
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

    // MARK: - Positional Write (Internal)

    /// Writes bytes at an absolute file offset using pwrite(2) / WriteFile+OVERLAPPED.
    ///
    /// This is an internal primitive for positional writes. Unlike `write(_:)`, this
    /// does not use or update the file's current position.
    ///
    /// - Parameters:
    ///   - buffer: The bytes to write.
    ///   - offset: Absolute file offset to write at.
    /// - Returns: Number of bytes written (single syscall, may be partial).
    /// - Throws: `File.Handle.Error` on failure.
    ///
    /// ## ESPIPE Policy
    /// - If offset == 0 and ESPIPE: falls back to sequential write(2)
    /// - If offset > 0 and ESPIPE: throws error (positional write not supported)
    ///
    /// ## Partial Writes
    /// Returns bytes written from single syscall. Caller must loop for full write.
    @usableFromInline
    package mutating func _pwrite(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(File.Handle.Error) -> Int {
        guard _descriptor.isValid else { throw .invalidHandle }
        guard !buffer.isEmpty else { return 0 }
        guard let base = buffer.baseAddress else { return 0 }

        #if os(Windows)
            guard let handle = _descriptor.rawHandle else { throw .invalidHandle }

            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(truncatingIfNeeded: UInt64(bitPattern: offset) & 0xFFFF_FFFF)
            overlapped.OffsetHigh = DWORD(truncatingIfNeeded: UInt64(bitPattern: offset) >> 32)

            var bytesWritten: DWORD = 0
            let success = WriteFile(
                handle,
                base,
                DWORD(truncatingIfNeeded: buffer.count),
                &bytesWritten,
                &overlapped
            )

            guard _ok(success) else {
                let error = GetLastError()
                // ERROR_INVALID_PARAMETER may indicate non-seekable handle
                if error == ERROR_INVALID_PARAMETER && offset > 0 {
                    throw .seekFailed(
                        offset: offset,
                        origin: .start,
                        errno: Int32(error),
                        message: "Positional write not supported on this handle"
                    )
                }
                throw .writeFailed(errno: Int32(error), message: "WriteFile with OVERLAPPED failed")
            }

            return Int(bytesWritten)

        #elseif canImport(Darwin)
            while true {
                let result = Darwin.pwrite(_descriptor.rawValue, base, buffer.count, off_t(offset))

                if result >= 0 {
                    return result
                }

                let e = errno
                if e == EINTR { continue }

                // ESPIPE: not a seekable file (pipe, socket, etc.)
                if e == ESPIPE {
                    if offset == 0 {
                        // Fallback to sequential write for offset 0
                        return try _writeSequentialFallback(base: base, count: buffer.count)
                    } else {
                        throw .seekFailed(
                            offset: offset,
                            origin: .start,
                            errno: e,
                            message: "pwrite not supported on this file type at non-zero offset"
                        )
                    }
                }

                throw .writeFailed(errno: e, message: String(cString: strerror(e)))
            }

        #elseif canImport(Glibc)
            while true {
                let result = Glibc.pwrite(_descriptor.rawValue, base, buffer.count, off_t(offset))

                if result >= 0 {
                    return result
                }

                let e = errno
                if e == EINTR { continue }

                if e == ESPIPE {
                    if offset == 0 {
                        return try _writeSequentialFallback(base: base, count: buffer.count)
                    } else {
                        throw .seekFailed(
                            offset: offset,
                            origin: .start,
                            errno: e,
                            message: "pwrite not supported on this file type at non-zero offset"
                        )
                    }
                }

                throw .writeFailed(errno: e, message: String(cString: strerror(e)))
            }

        #elseif canImport(Musl)
            while true {
                let result = Musl.pwrite(_descriptor.rawValue, base, buffer.count, off_t(offset))

                if result >= 0 {
                    return result
                }

                let e = errno
                if e == EINTR { continue }

                if e == ESPIPE {
                    if offset == 0 {
                        return try _writeSequentialFallback(base: base, count: buffer.count)
                    } else {
                        throw .seekFailed(
                            offset: offset,
                            origin: .start,
                            errno: e,
                            message: "pwrite not supported on this file type at non-zero offset"
                        )
                    }
                }

                throw .writeFailed(errno: e, message: String(cString: strerror(e)))
            }
        #endif
    }

    #if !os(Windows)
    /// Fallback to sequential write when pwrite fails with ESPIPE at offset 0.
    @usableFromInline
    internal mutating func _writeSequentialFallback(
        base: UnsafeRawPointer,
        count: Int
    ) throws(File.Handle.Error) -> Int {
        while true {
            #if canImport(Darwin)
            let result = Darwin.write(_descriptor.rawValue, base, count)
            #elseif canImport(Glibc)
            let result = Glibc.write(_descriptor.rawValue, base, count)
            #elseif canImport(Musl)
            let result = Musl.write(_descriptor.rawValue, base, count)
            #endif

            if result >= 0 { return result }

            let e = errno
            if e == EINTR { continue } // Retry on interrupt
            throw .writeFailed(errno: e, message: String(cString: strerror(e)))
        }
    }
    #endif

    /// Writes all bytes at an absolute file offset, looping for partial writes.
    ///
    /// This is a convenience wrapper around `_pwrite` that ensures all bytes are written.
    ///
    /// - Parameters:
    ///   - buffer: The bytes to write.
    ///   - offset: Absolute file offset to start writing at.
    /// - Throws: `File.Handle.Error` on failure.
    @usableFromInline
    package mutating func _pwriteAll(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(File.Handle.Error) {
        guard !buffer.isEmpty else { return }

        var totalWritten = 0
        var currentOffset = offset

        while totalWritten < buffer.count {
            let remaining = UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written = try _pwrite(remaining, at: currentOffset)
            if written == 0 {
                // Should not happen for regular files, but guard against infinite loop
                throw .writeFailed(errno: 0, message: "pwrite returned 0 bytes written")
            }
            totalWritten += written
            currentOffset += Int64(written)
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
        from origin: Seek.Origin = .start
    ) throws(File.Handle.Error) -> Int64 {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        #if os(Windows)
            guard let handle = _descriptor.rawHandle else {
                throw .invalidHandle
            }
            var newPosition: LARGE_INTEGER = LARGE_INTEGER()
            var distance: LARGE_INTEGER = LARGE_INTEGER()
            distance.QuadPart = offset

            let whence: DWORD
            switch origin {
            case .start: whence = _dword(FILE_BEGIN)
            case .current: whence = _dword(FILE_CURRENT)
            case .end: whence = _dword(FILE_END)
            }

            guard _ok(SetFilePointerEx(handle, distance, &newPosition, whence))
            else {
                throw .seekFailed(offset: offset, origin: origin, errno: Int32(GetLastError()), message: "SetFilePointerEx failed")
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
                throw .seekFailed(offset: offset, origin: origin, errno: errno, message: String(cString: strerror(errno)))
            }
            return Int64(result)
        #endif
    }

    /// Syncs the file to disk.
    ///
    /// - Throws: `File.Handle.Error` on failure.
    public mutating func sync() throws(File.Handle.Error) {
        guard _descriptor.isValid else {
            throw .invalidHandle
        }

        #if os(Windows)
            guard let handle = _descriptor.rawHandle else {
                throw .invalidHandle
            }
            guard FlushFileBuffers(handle) else {
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
    public consuming func close() throws(File.Handle.Error) {
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
