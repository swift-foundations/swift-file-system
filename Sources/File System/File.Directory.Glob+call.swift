public import Glob_Primitives
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {

    @inlinable
    public func callAsFunction(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [Match] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [Match] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if File.System.Stat.isDirectory(at: path) {
                results.append(Match(directory: File.Directory(path)))
            } else {
                results.append(Match(file: File(path)))
            }
        }
        return results
    }

    @inlinable
    public func callAsFunction(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [Match] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [Match] in
            try glob.callAsFunction(include: include, excluding: excluding, options: options)
        }
    }

    @inlinable
    public func callAsFunction(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) throws(Glob.Error) -> [Match] {
        let paths = try matchPaths(include: include, excluding: excluding, options: options)
        var results: [Match] = []
        for pathString in paths {
            let path = File.Path(__unchecked: (), pathString)
            if File.System.Stat.isDirectory(at: path) {
                results.append(Match(directory: File.Directory(path)))
            } else {
                results.append(Match(file: File(path)))
            }
        }
        return results
    }

    @inlinable
    public func callAsFunction(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [Match] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [Match] in
            try glob.callAsFunction(include: include, excluding: excluding, options: options)
        }
    }
}
