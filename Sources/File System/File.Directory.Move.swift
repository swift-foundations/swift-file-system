public import IO
public import Thread_Pool

extension File.Directory {

    public struct Move: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory.Move {

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        try File.System.Move.move(from: path, to: destination.path, options: options)
        return destination
    }

    @discardableResult
    @inlinable
    public func rename(
        to newName: File.Path.Component,
        options: File.System.Move.Options = .init()
    ) throws(File.System.Move.Error) -> File.Directory {
        guard let parent = path.parent else {

            throw .rename(.invalidArgument)
        }
        let destination = parent / newName
        try File.System.Move.move(from: path, to: destination, options: options)
        return File.Directory(destination)
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Path,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination, options: options)
        }
        return File.Directory(destination)
    }

    @discardableResult
    @inlinable
    public func to(
        _ destination: File.Directory,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination.path, options: options)
        }
        return destination
    }

    @discardableResult
    @inlinable
    public func rename(
        to newName: File.Path.Component,
        options: File.System.Move.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, File.System.Move.Error>) -> File.Directory {
        guard let parent = path.parent else {

            throw .right(.rename(.invalidArgument))
        }
        let destination = parent / newName
        let source = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Move.Error) in
            try File.System.Move.move(from: source, to: destination, options: options)
        }
        return File.Directory(destination)
    }
}

extension File.Directory {

    public var move: Move {
        Move(path)
    }
}
