public import IO
import Kernel
public import Thread_Pool

extension File {

    public struct Write: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Write {

    @inlinable
    public func atomic(
        _ bytes: borrowing Swift.Span<Byte>,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(bytes, to: path, options: options)
    }

    @inlinable
    public func atomic(
        _ string: Swift.String,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) {
        let utf8 = [Byte](string.utf8)
        try atomic(utf8.span, options: options)
    }

    @inlinable
    public func atomic<S: Swift.Sequence>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) throws(File.System.Write.Atomic.Error) where S.Element == Byte {
        let array = Array(bytes)
        try atomic(array.span, options: options)
    }

    @inlinable
    public func atomic(
        _ string: Swift.String,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Atomic.Error) in
            let utf8 = [Byte](string.utf8)
            try File.System.Write.Atomic.write(utf8.span, to: path, options: options)
        }
    }

    @inlinable
    public func atomic<S: Swift.Sequence & Sendable>(
        contentsOf bytes: S,
        options: File.System.Write.Atomic.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>)
    where S.Element == Byte {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Atomic.Error) in
            let array = Array(bytes)
            try File.System.Write.Atomic.write(array.span, to: path, options: options)
        }
    }

    @inlinable
    public func append(_ bytes: borrowing Swift.Span<Byte>) throws(File.System.Write.Append.Error) {
        try File.System.Write.Append.append(bytes, to: path)
    }

    @inlinable
    public func append(_ string: Swift.String) throws(File.System.Write.Append.Error) {
        let utf8 = [Byte](string.utf8)
        try append(utf8.span)
    }

    @inlinable
    public func append(
        _ string: Swift.String
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Append.Error>) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Append.Error) in
            let utf8 = [Byte](string.utf8)
            try File.System.Write.Append.append(utf8.span, to: path)
        }
    }

    @inlinable
    public func streaming<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) throws(File.System.Write.Streaming.Error) where Chunks.Element == [Byte] {
        try File.System.Write.Streaming.write(chunks, to: path, options: options)
    }

    @inlinable
    public func streaming<Chunks: Swift.Sequence & Sendable>(
        _ chunks: Chunks,
        options: File.System.Write.Streaming.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Streaming.Error>)
    where Chunks.Element == [Byte] {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Write.Streaming.Error) in
            try File.System.Write.Streaming.write(chunks, to: path, options: options)
        }
    }
}

extension File {

    public var write: File.Write {
        Self.Write(path)
    }
}
