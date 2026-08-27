public import Kernel

extension File.System.Write {

    public enum Append {}
}

extension File.System.Write.Append {

    public enum Error: Swift.Error, Sendable {

        case open(Kernel.File.Open.Error)

        case write(Kernel.IO.Write.Error)

        case shortWrite(written: Int, expected: Int)
    }
}

extension File.System.Write.Append.Error {

    public var isNotFound: Bool {
        switch self {
        case .open(let e):
            if case .path(.notFound) = e { return true }
            return false

        default:
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        default:
            return false
        }
    }

    public var isDirectory: Bool {
        switch self {
        case .open(let e):
            if case .path(.isDirectory) = e { return true }
            return false

        default:
            return false
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isReadOnly { return true }
            return false

        default:
            return false
        }
    }

    public var isNoSpace: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isNoSpace { return true }
            return false

        case .write(let e):
            if case .platform(let p) = e, p.code.isNoSpace { return true }
            return false

        case .shortWrite:
            return false
        }
    }
}

extension File.System.Write.Append {

    @usableFromInline
    internal static func advance(
        totalWritten: Int,
        by writtenThisCall: Int,
        expected: Int
    ) throws(Self.Error) -> Int {
        guard writtenThisCall > 0 else {
            throw .shortWrite(written: totalWritten, expected: expected)
        }
        return totalWritten + writtenThisCall
    }
}

extension File.System.Write.Append {

    public static func append(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing File.Path
    ) throws(Self.Error) {

        var descriptor: Kernel.Descriptor = .invalid
        do throws(Kernel.File.Open.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                descriptor = try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: .write,
                    options: [.create, .append],
                    permissions: Kernel.File.Permissions(rawValue: 0o644)
                )
            }
        } catch {
            throw .open(error)
        }

        if bytes.count == 0 { return }

        try bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) throws(Self.Error) in
            try unsafe writeAll(descriptor, from: rawBuffer)
        }
    }

    private static func writeAll(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Self.Error) {
        var totalWritten = 0
        while totalWritten < buffer.count {
            let slice = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written: Int
            do throws(Kernel.IO.Write.Error) {
                written = try unsafe Kernel.IO.Write.write(descriptor, from: slice)
            } catch {

                #if !os(Windows)
                    if case .platform(let kernelError) = error,
                        kernelError.code == Error.Error.Code.POSIX.EINTR
                    {
                        continue
                    }
                #endif
                throw .write(error)
            }
            totalWritten = try Self.advance(
                totalWritten: totalWritten,
                by: written,
                expected: buffer.count
            )
        }
    }
}

extension File.System.Write.Append {

    public static func append<S: Binary.Serializable>(
        _ value: S,
        to path: borrowing File.Path
    ) throws(Self.Error) {
        try S.withSerializedBytes(value) {
            (span: borrowing Swift.Span<Byte>) throws(Self.Error) in
            try append(span, to: path)
        }
    }

}

extension File.System.Write.Append.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .open(let error):
            return "Open failed: \(error)"

        case .write(let error):
            return "Write failed: \(error)"

        case .shortWrite(let written, let expected):
            return "Short write: wrote \(written) of \(expected) bytes, write() returned 0"
        }
    }
}
