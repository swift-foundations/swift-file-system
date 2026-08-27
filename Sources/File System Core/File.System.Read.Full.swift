import Binary
import Either
public import Kernel

extension File.System.Read {

    public enum Full {}
}

extension File.System.Read.Full {

    public enum Error: Swift.Error, Sendable {

        case open(Kernel.File.Open.Error)

        case stat(Kernel.File.Stats.Error)

        case read(Kernel.IO.Read.Error)

        case isDirectory(File.Path)
    }
}

extension File.System.Read.Full.Error {

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
        case .isDirectory:
            return true

        case .open(let e):
            if case .path(.isDirectory) = e { return true }
            return false

        default:
            return false
        }
    }

    public var isTooManyOpenFiles: Bool {
        switch self {
        case .open(let e):
            if case .handle(.limit) = e { return true }
            return false

        default:
            return false
        }
    }
}

extension File.System.Read.Full {

    public static func read<R, E: Swift.Error>(
        from path: borrowing File.Path,
        body: (Swift.Span<Byte>) throws(E) -> R
    ) throws(Either<File.System.Read.Full.Error, E>) -> R {

        var descriptor: Kernel.Descriptor = .invalid
        do throws(Kernel.File.Open.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                descriptor = try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: .read,
                    options: [],
                    permissions: Kernel.File.Permissions(rawValue: 0)
                )
            }
        } catch {
            throw .left(.open(error))
        }

        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try Kernel.File.Stats.get(descriptor: descriptor)
        } catch {
            throw .left(.stat(error))
        }

        if case .directory = stats.type {
            throw .left(.isDirectory(copy path))
        }

        let fileSize = Int(stats.size.underlying)

        if fileSize == 0 {
            let empty: [Byte] = []
            do throws(E) {
                return try body(empty.span)
            } catch {
                throw .right(error)
            }
        }

        let buffer: [Byte]
        do throws(Kernel.IO.Read.Error) {
            buffer = try readAll(descriptor: descriptor, size: fileSize)
        } catch {
            throw .left(.read(error))
        }

        do throws(E) {
            return try body(buffer.span)
        } catch {
            throw .right(error)
        }
    }

}

extension File.System.Read.Full {

    private static func readAll(
        descriptor: borrowing Kernel.Descriptor,
        size: Int
    ) throws(Kernel.IO.Read.Error) -> [Byte] {
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 1)
        defer { unsafe buffer.deallocate() }

        var totalRead = 0
        while totalRead < size {
            let slice = unsafe UnsafeMutableRawBufferPointer(
                start: buffer.baseAddress!.advanced(by: totalRead),
                count: size - totalRead
            )
            do throws(Kernel.IO.Read.Error) {
                let bytesRead = try unsafe Kernel.IO.Read.pread(
                    descriptor,
                    into: slice,
                    at: Kernel.File.Offset(Int64(totalRead))
                )
                guard bytesRead > 0 else { break }
                totalRead += bytesRead
            } catch {

                #if !os(Windows)
                    if case .platform(let kernelError) = error,
                        kernelError.code == Error.Error.Code.POSIX.EINTR
                    {
                        continue
                    }
                #endif
                throw error
            }
        }

        let typedBuf = unsafe buffer.bindMemory(to: Byte.self)
        return unsafe Array(
            UnsafeBufferPointer<Byte>(start: typedBuf.baseAddress, count: totalRead)
        )
    }
}

extension File.System.Read.Full.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .open(let error):
            return "Open failed: \(error)"

        case .stat(let error):
            return "Stat failed: \(error)"

        case .read(let error):
            return "Read failed: \(error)"

        case .isDirectory(let path):
            return "Is a directory: \(path)"
        }
    }
}
