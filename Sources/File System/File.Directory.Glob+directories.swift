public import Glob
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {

    @inlinable
    public func directories(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [File.Directory] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [File.Directory] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if File.System.Stat.isDirectory(at: path) {
                results.append(File.Directory(path))
            }
        }
        return results
    }

    @inlinable
    public func directories(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File.Directory] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run {
            () throws(Glob.Error) -> [File.Directory] in
            try glob.directories(include: include, excluding: excluding, options: options)
        }
    }

    @inlinable
    public func directories(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [File.Directory] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [File.Directory] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if File.System.Stat.isDirectory(at: path) {
                results.append(File.Directory(path))
            }
        }
        return results
    }

    @inlinable
    public func directories(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File.Directory] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run {
            () throws(Glob.Error) -> [File.Directory] in
            try glob.directories(include: include, excluding: excluding, options: options)
        }
    }
}
