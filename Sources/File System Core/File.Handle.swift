public import Kernel

extension File {

    public struct Handle: ~Copyable, Sendable {

        @usableFromInline
        internal var _descriptor: File.Descriptor

        public let mode: Kernel.File.Open.Mode

        public let path: File.Path

        @usableFromInline
        internal init(
            descriptor: consuming File.Descriptor,
            mode: Kernel.File.Open.Mode,
            path: File.Path
        ) {
            self._descriptor = descriptor
            self.mode = mode
            self.path = path
        }
    }
}

extension File.Handle {

    @inlinable
    public static func open(
        _ path: borrowing File.Path,
        mode: Kernel.File.Open.Mode,
        options: Kernel.File.Open.Options = [.execClose]
    ) throws(Kernel.File.Open.Error) -> File.Handle {
        let descriptor = try File.Descriptor.open(path, mode: mode, options: options)
        return File.Handle(descriptor: descriptor, mode: mode, path: copy path)
    }

    @inlinable
    public mutating func read(count: Int) throws(Kernel.IO.Read.Error) -> [Byte] {
        guard count > 0 else { return [] }

        let rawBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { unsafe rawBuffer.deallocate() }

        let bytesRead = try unsafe Kernel.IO.Read.read(
            _descriptor.kernelDescriptor,
            into: rawBuffer
        )

        return unsafe Array(UnsafeRawBufferPointer(start: rawBuffer.baseAddress, count: bytesRead))
            .map(Byte.init)
    }

    @inlinable
    public mutating func read(
        into buffer: UnsafeMutableRawBufferPointer
    ) throws(Kernel.IO.Read.Error) -> Int {
        guard unsafe !buffer.isEmpty else { return 0 }
        return try unsafe Kernel.IO.Read.read(_descriptor.kernelDescriptor, into: buffer)
    }

    @inlinable
    public mutating func write(_ bytes: borrowing Swift.Span<Byte>) throws(File.Handle.Error) {
        if bytes.count == 0 { return }
        try bytes.withUnsafeBytes {
            (rawBuffer: UnsafeRawBufferPointer) throws(File.Handle.Error) in
            try unsafe writeAll(rawBuffer)
        }
    }

    @inlinable
    package mutating func writeAll(
        _ buffer: UnsafeRawBufferPointer
    ) throws(File.Handle.Error) {
        var totalWritten = 0
        while totalWritten < buffer.count {
            let remaining = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written: Int
            do throws(Kernel.IO.Write.Error) {
                written = try unsafe Kernel.IO.Write.write(
                    _descriptor.kernelDescriptor,
                    from: remaining
                )
            } catch {
                throw .write(error)
            }
            totalWritten = try Self.advance(
                totalWritten: totalWritten,
                by: written,
                expected: buffer.count
            )
        }
    }

    @usableFromInline
    package mutating func pwrite(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(Kernel.IO.Write.Error) -> Int {
        guard unsafe !buffer.isEmpty else { return 0 }

        do throws(Kernel.IO.Write.Error) {
            return try unsafe Kernel.IO.Write.pwrite(
                _descriptor.kernelDescriptor,
                from: buffer,
                at: Kernel.File.Offset(offset)
            )
        } catch let error {

            #if !os(Windows)
                if case .platform(let p) = error, p.code == .POSIX.ESPIPE, offset == 0 {
                    return try unsafe Kernel.IO.Write.write(
                        _descriptor.kernelDescriptor,
                        from: buffer
                    )
                }
            #endif
            throw error
        }
    }

    @usableFromInline
    package mutating func pwriteAll(
        _ buffer: UnsafeRawBufferPointer,
        at offset: Int64
    ) throws(File.Handle.Error) {
        guard unsafe !buffer.isEmpty else { return }

        var totalWritten = 0
        var currentOffset = offset

        while totalWritten < buffer.count {
            let remaining = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written: Int
            do throws(Kernel.IO.Write.Error) {
                written = try unsafe pwrite(remaining, at: currentOffset)
            } catch {
                throw .write(error)
            }
            totalWritten = try Self.advance(
                totalWritten: totalWritten,
                by: written,
                expected: buffer.count
            )
            currentOffset += Int64(written)
        }
    }

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

    @inlinable
    public mutating func sync() throws(Kernel.File.Flush.Error) {
        try Kernel.File.Flush.flush(_descriptor.kernelDescriptor)
    }

    @inlinable
    public consuming func close() throws(Kernel.Close.Error) {
        try _descriptor.close()
    }
}

extension File.Handle {

    @inlinable
    public var isValid: Bool {
        _descriptor.isValid
    }
}
