import Kernel

extension File.Directory.Contents {

    public struct Iterator: IteratorProtocol {
        internal let _stream: Kernel.Directory.Stream
        internal var _finished: Bool = false
        internal var _lastError: Kernel.Directory.Error? = nil

        internal init(stream: Kernel.Directory.Stream) {
            self._stream = stream
        }
    }
}

extension File.Directory.Contents.Iterator {
    public mutating func next() -> File.Name? {
        guard !_finished else { return nil }

        do throws(Kernel.Directory.Error) {
            guard let entry = try _stream.next() else {
                _finished = true
                return nil
            }

            if entry.isDotOrDotDot {
                return next()
            }

            return File.Name(from: entry)
        } catch {
            _finished = true
            _lastError = error
            return nil
        }
    }
}

extension File.Directory.Contents {

    public static func makeIterator(
        at directory: File.Directory
    ) throws(Self.Error) -> (iterator: Iterator, handle: IteratorHandle) {
        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try directory.path.withKernelPath {
                kernelPath throws(Kernel.Directory.Error) in
                try Kernel.Directory.open(at: kernelPath)
            }
        } catch {
            throw mapKernelError(error, path: directory.path)
        }

        let handle = IteratorHandle(stream: stream)
        return (Iterator(stream: stream), handle)
    }

    public static func closeIterator(_ handle: IteratorHandle) {
        handle.stream.close()
    }

    public static func iteratorError(
        for iterator: Iterator,
        directory: File.Directory
    ) -> File.Directory.Contents.Error? {
        guard let kernelError = iterator._lastError else {
            return nil
        }
        return mapKernelReadError(kernelError, path: directory.path)
    }
}

extension File.Directory.Contents {

    private static func mapKernelReadError(
        _ error: Kernel.Directory.Error,
        path: File.Path
    ) -> File.Directory.Contents.Error {
        switch error {
        case .io:
            return .readFailed(errno: 0, message: "I/O error during iteration")

        case .platform(let kernelError):
            let errno = kernelError.code.posix ?? Int32(kernelError.code.win32 ?? 0)
            return .readFailed(errno: errno, message: "\(kernelError)")

        default:
            return .readFailed(errno: 0, message: "\(error)")
        }
    }
}
