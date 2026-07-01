//
//  File.Directory.Glob+files.swift
//  swift-file-system
//
//  Glob files() variant.
//

public import Glob_Primitives
public import IO
import Kernel
public import Thread_Pool

extension File.Directory.Glob {
    /// Matches files only against pre-compiled glob patterns.
    ///
    /// Typed canonical variant. Callers holding parsed ``Glob/Pattern`` values
    /// SHOULD prefer this overload over the `[Swift.String]` convenience to
    /// avoid re-parsing at the dispatch boundary.
    ///
    /// ## Example
    /// ```swift
    /// let includes = try ["**/*.swift"].map(Glob.Pattern.init)
    /// let swiftFiles = try dir.glob.files(include: includes)
    /// ```
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching files.
    /// - Throws: `Glob.Error` on failure.
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

    /// Matches files only against pre-compiled glob patterns (async).
    ///
    /// Async variant of ``files(include:excluding:options:)-{Glob.Pattern overload}``;
    /// runs blocking I/O on a dedicated thread pool.
    ///
    /// - Parameters:
    ///   - include: Pre-compiled patterns to include.
    ///   - excluding: Pre-compiled patterns to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching files.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
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

    /// Matches files only (parsing convenience for string patterns).
    ///
    /// Equivalent to `glob(include:excluding:options:).compactMap(\.file)`.
    /// Parses each pattern string into ``Glob/Pattern`` and delegates to the
    /// typed overload. Callers that hold pre-compiled patterns SHOULD prefer
    /// the typed overload to avoid re-parsing.
    ///
    /// ## Example
    /// ```swift
    /// let swiftFiles = try dir.glob.files(include: ["**/*.swift"])
    /// for file in swiftFiles {
    ///     print(file.path)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include.
    ///   - excluding: Pattern strings to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching files.
    /// - Throws: `Glob.Error` on failure (including pattern-parse errors).
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

    /// Matches files only (parsing convenience for string patterns, async).
    ///
    /// Async variant - runs blocking I/O on a dedicated thread pool.
    ///
    /// - Parameters:
    ///   - include: Pattern strings to include.
    ///   - excluding: Pattern strings to exclude.
    ///   - options: Optional matching/traversal options.
    /// - Returns: Matching files.
    /// - Throws: `Either<Kernel.Thread.Pool.Error, Glob.Error>` on failure.
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
