//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

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
    /// An owning file handle.
    ///
    /// Sendable because all fields are Sendable (descriptor is just a number).
    /// ~Copyable enforces single-ownership (prevents double-close).
    public struct Handle: ~Copyable, Sendable {
        /// The underlying file descriptor.
        @usableFromInline
        internal var _descriptor: File.Descriptor
        /// The mode this handle was opened with.
        public let mode: Kernel.File.Open.Mode
        /// The path this handle was opened for.
        public let path: File.Path

        /// Creates a handle from an existing descriptor.
        @usableFromInline
        internal init(descriptor: consuming File.Descriptor, mode: Kernel.File.Open.Mode, path: File.Path) {
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
    ///   - mode: The access mode (use `Kernel.File.Open.Mode`).
    ///   - options: Additional options (use `Kernel.File.Open.Options`).
    /// - Returns: A file handle.
    /// - Throws: `Kernel.File.Open.Error` on failure.
    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options = [.execClose]
    ) throws(Kernel.File.Open.Error) -> File.Handle {
        let descriptor = try File.Descriptor.open(path, mode: mode, options: options)
        return File.Handle(descriptor: descriptor, mode: mode, path: copy path)
    }

    /// Reads up to `count` bytes from the file.
    ///
    /// This is a single-syscall primitive. It returns whatever bytes are available
    /// up to `count`, which may be fewer than requested even before EOF.
    /// Callers who need exactly `count` bytes should loop or use `Read.Full`.
    ///
    /// - Parameter count: Maximum number of bytes to read.
    /// - Returns: The bytes read (may be fewer than requested at EOF or partial read).
    /// - Throws: `Kernel.IO.Read.Error` on failure.
    @inlinable
    public mutating func read(count: Int) throws(Kernel.IO.Read.Error) -> [Byte] {
        guard count > 0 else { return [] }

        // Allocate raw buffer to avoid closure that breaks typed throws
        let rawBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { unsafe rawBuffer.deallocate() }

        let bytesRead = try unsafe Kernel.IO.Read.read(_descriptor.kernelDescriptor, into: rawBuffer)

        // Copy to array — byte-domain return type
        return unsafe Array(UnsafeRawBufferPointer(start: rawBuffer.baseAddress, count: bytesRead)).map(Byte.init)
    }

    /// Reads bytes into a caller-provided buffer.
    ///
    /// This is the canonical zero-allocation read API. Callers provide the destination buffer.
    ///
    /// - Parameter buffer: Destination buffer. Must remain valid for duration of call.
    /// - Returns: Number of bytes read (0 at EOF).
    /// - Note: May return fewer bytes than buffer size (partial read).
    @inlinable
    public mutating func read(
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(Kernel.IO.Read.Error) -> Int {
        guard unsafe !buffer.isEmpty else { return 0 }
        return try unsafe Kernel.IO.Read.read(_descriptor.kernelDescriptor, into: buffer)
    }

    /// Writes bytes to the file.
    ///
    /// - Parameter bytes: The bytes to write.
    /// - Throws: `Kernel.IO.Write.Error` on failure.
    @inlinable
    public mutating func write(_ bytes: borrowing Swift.Span<Byte>) throws(Kernel.IO.Write.Error) {
        if bytes.count == 0 { return }
        try unsafe bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) throws(Kernel.IO.Write.Error) in
            try unsafe writeAll(rawBuffer)
        }
    }

    /// Writes all bytes from a raw buffer, looping for partial writes.
    @inlinable
    internal mutating func writeAll(
        _ buffer: UnsafeRawBufferPointer
    ) throws(Kernel.IO.Write.Error) {
        var totalWritten = 0
        while totalWritten < buffer.count {
            let remaining = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written = try unsafe Kernel.IO.Write.write(
                _descriptor.kernelDescriptor,
                from: remaining
            )
            guard written > 0 else { return }
            totalWritten += written
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
    /// - Throws: `Kernel.IO.Write.Error` on failure.
    ///
    /// ## Partial Writes
    /// Returns bytes written from single syscall. Caller must loop for full write.
    @usableFromInline
    package mutating func pwrite(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.IO.Write.Error) -> Int {
        guard unsafe !buffer.isEmpty else { return 0 }

        do {
            return try unsafe Kernel.IO.Write.pwrite(
                _descriptor.kernelDescriptor,
                from: buffer,
                at: Kernel.File.Offset(offset)
            )
        } catch let error {
            // Check for pipe/socket - not seekable at offset 0, fallback to sequential
            if case .platform(let p) = error, p.code == .POSIX.ESPIPE, offset == 0 {
                return try unsafe Kernel.IO.Write.write(_descriptor.kernelDescriptor, from: buffer)
            }
            throw error
        }
    }

    /// Writes all bytes at an absolute file offset, looping for partial writes.
    ///
    /// This is a convenience wrapper around `pwrite` that ensures all bytes are written.
    ///
    /// - Parameters:
    ///   - buffer: The bytes to write.
    ///   - offset: Absolute file offset to start writing at.
    /// - Throws: `Kernel.IO.Write.Error` on failure.
    @usableFromInline
    package mutating func pwriteAll(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.IO.Write.Error) {
        guard unsafe !buffer.isEmpty else { return }

        var totalWritten = 0
        var currentOffset = offset

        while totalWritten < buffer.count {
            let remaining = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written = try unsafe pwrite(remaining, at: currentOffset)
            if written == 0 {
                // Should not happen for regular files, but guard against infinite loop
                return
            }
            totalWritten += written
            currentOffset += Int64(written)
        }
    }

    /// Seeks to a position in the file.
    ///
    /// - Parameters:
    ///   - offset: The offset to seek to.
    ///   - whence: The reference point for the seek (use `Kernel.File.Seek.Whence`).
    /// - Returns: The new position in the file.
    /// - Throws: `Kernel.File.Seek.Error` on failure.
    @discardableResult
    @inlinable
    public mutating func seek(
        to offset: Int64,
        from whence: Kernel.File.Seek.Whence = .start
    ) throws(Kernel.File.Seek.Error) -> Int64 {
        try Kernel.File.Seek.seek(
            _descriptor.kernelDescriptor,
            offset: offset,
            whence: whence
        )
    }

    /// Syncs the file to disk.
    ///
    /// - Throws: `Kernel.File.Flush.Error` on failure.
    @inlinable
    public mutating func sync() throws(Kernel.File.Flush.Error) {
        try Kernel.File.Flush.flush(_descriptor.kernelDescriptor)
    }

    /// Closes the handle.
    ///
    /// - Postcondition: `isValid == false`
    /// - Note: Closing an already-closed handle returns without error.
    /// - Throws: `Kernel.Close.Error` on close failure.
    @inlinable
    public consuming func close() throws(Kernel.Close.Error) {
        try _descriptor.close()
    }
}

// MARK: - Properties

extension File.Handle {
    /// Whether this handle is valid (not closed).
    @inlinable
    public var isValid: Bool {
        _descriptor.isValid
    }
}
