public import IO
import Kernel
public import Thread_Pool

extension File {

    public struct Read: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Read {

    @inlinable
    public func full<R, E: Swift.Error>(
        _ body: (Swift.Span<Byte>) throws(E) -> R
    ) throws(Either<File.System.Read.Full.Error, E>) -> R {
        try File.System.Read.Full.read(from: path, body: body)
    }

    @inlinable
    public func full<R: Sendable, E: Swift.Error>(
        _ body: @escaping @Sendable (Swift.Span<Byte>) throws(E) -> R
    ) async throws(Either<Kernel.Thread.Pool.Error, Either<File.System.Read.Full.Error, E>>) -> R {
        let path = self.path
        return try await Kernel.Thread.Pool.shared.run {
            () throws(Either<File.System.Read.Full.Error, E>) -> R in
            try File.System.Read.Full.read(from: path, body: body)
        }
    }
}

extension File {

    public var read: Read {
        Read(path)
    }
}
