//
//  File.Directory.Glob+directories.swift
//  swift-file-system
//
//  Glob directories() variant.
//

public import Glob_Primitives
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {
    /// Matches directories only against pre-compiled glob patterns.
    ///
    /// Typed canonical variant. Callers holding parsed ``Glob/Pattern`` values
    /// SHOULD prefer this overload over the `[Swift.String]` convenience.
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching directories.
    /// - Throws: `Glob.Error` on failure.
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

    /// Matches directories only against pre-compiled glob patterns (async).
    ///
    /// Async variant of ``directories(include:excluding:options:)-{Glob.Pattern overload}``.
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching directories.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
    @inlinable
    public func directories(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File.Directory] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [File.Directory] in
            try glob.directories(include: include, excluding: excluding, options: options)
        }
    }

    /// Matches directories only (parsing convenience for string patterns).
    ///
    /// Parses each pattern string into ``Glob/Pattern`` and delegates to the
    /// typed overload.
    ///
    /// ## Example
    /// ```swift
    /// let subdirs = try dir.glob.directories(include: ["*/"])
    /// for subdir in subdirs {
    ///     print(subdir.path)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include.
    ///   - excluding: Pattern strings to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching directories.
    /// - Throws: `Glob.Error` on failure (including pattern-parse errors).
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

    /// Matches directories only (parsing convenience for string patterns, async).
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include.
    ///   - excluding: Pattern strings to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching directories.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
    @inlinable
    public func directories(
        include: [Swift.String],
        excluding: [Swift.String] = [],
        options: Glob.Options = .init()
    ) async throws(Either<Kernel.Thread.Pool.Error, Glob.Error>) -> [File.Directory] {
        let glob = self
        return try await Kernel.Thread.Pool.shared.run { () throws(Glob.Error) -> [File.Directory] in
            try glob.directories(include: include, excluding: excluding, options: options)
        }
    }
}
