public import Glob
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {

    @inlinable
    public func files(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [File] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [File] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if !File.System.Stat.isDirectory(at: path) {
                results.append(File(path))
            }
        }
        return results
    }

    @inlinable
    public func files(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [File] in
            try glob.files(include: include, excluding: excluding, options: options)
        }
    }

    @inlinable
    public func files(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [File] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [File] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if !File.System.Stat.isDirectory(at: path) {
                results.append(File(path))
            }
        }
        return results
    }

    @inlinable
    public func files(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [File] in
            try glob.files(include: include, excluding: excluding, options: options)
        }
    }
}
