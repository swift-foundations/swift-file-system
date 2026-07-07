//
//  File.Directory.Glob+call.swift
//  swift-file-system
//
//  Primary glob callAsFunction implementations.
//

public import Glob_Primitives
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {
    /// Matches entries against pre-compiled glob patterns.
    ///
    /// Typed canonical variant. Callers holding parsed ``Glob/Pattern`` values
    /// SHOULD prefer this overload over the `[Swift.String]` convenience.
    ///
    /// **Semantics:**
    /// - Returns both files and directories that match
    /// - Paths are absolute, anchored at this directory
    /// - Results are lexicographically sorted (deterministic) by default
    /// - Dotfiles follow `.explicit` policy by default (`*` doesn't match `.foo`)
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching entries as `Match` values.
    /// - Throws: `Glob.Error` on failure.
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

    /// Matches entries against pre-compiled glob patterns (async).
    ///
    /// Async variant of ``callAsFunction(include:excluding:options:)-{Glob.Pattern overload}``.
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching entries as `Match` values.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
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

    /// Matches entries (parsing convenience for string patterns).
    ///
    /// Parses each pattern string into ``Glob/Pattern`` and delegates to the
    /// typed overload.
    ///
    /// ## Example
    /// ```swift
    /// let matches = try dir.glob(include: ["**/*.swift"], excluding: ["**/Tests/**"])
    /// for match in matches {
    ///     if let file = match.file {
    ///         print("File: \(file.path)")
    ///     } else if let subdir = match.subdirectory {
    ///         print("Directory: \(subdir.path)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include, such as `"**/*.swift"`.
    ///   - excluding: Pattern strings to exclude, such as `"**/Tests/**"`.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching entries as `Match` values.
    /// - Throws: `Glob.Error` on failure (including pattern-parse errors).
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

    /// Matches entries (parsing convenience for string patterns, async).
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include.
    ///   - excluding: Pattern strings to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching entries as `Match` values.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
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
