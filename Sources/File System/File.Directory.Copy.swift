public import IO
public import Thread_Pool

extension File.Directory {

    public struct Copy: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory.Copy {

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File.Directory {
        try File.System.Copy.recursive(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) throws(File.System.Copy.Error) -> File.Directory {
        try File.System.Copy.recursive(from: path, to: destination.path, options: options)
        return destination
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Copy.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Copy.Error) in
            try File.System.Copy.recursive(from: source, to: destination, options: options)
        }
        return File.Directory(destination)
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Copy.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Copy.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Copy.Error) in
            try File.System.Copy.recursive(from: source, to: destination.path, options: options)
        }
        return destination
    }
}

extension File.Directory {

    public var copy: Copy {
        Copy(path)
    }
}
