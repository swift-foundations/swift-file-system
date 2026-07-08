//
//  File.Directory.Glob.swift
//  swift-file-system
//
//  Glob pattern matching for directories.
//

public import Glob_Primitives
public import IO

// MARK: - Glob Namespace

extension File.Directory {
    /// Namespace for glob pattern matching operations.
    ///
    /// Access via the `glob` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/path/to/project"
    ///
    /// // Common case - callable (match patterns)
    /// let matches = try dir.glob(include: ["**/*.swift"])
    ///
    /// // Variant - files only
    /// let files = try dir.glob.files(include: ["**/*.swift"])
    ///
    /// // Variant - directories only
    /// let dirs = try dir.glob.directories(include: ["*/"])
    /// ```
    public struct Glob: Sendable {
        /// The directory to search in.
        @usableFromInline
        let directory: File.Directory

        /// Creates a Glob instance.
        @usableFromInline
        internal init(_ directory: File.Directory) {
            self.directory = directory
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to glob operations.
    ///
    /// This property returns a callable namespace. Use it directly for the common case,
    /// or access variants via dot syntax:
    /// ```swift
    /// let matches = try dir.glob(include: ["**/*.swift"])
    /// let files = try dir.glob.files(include: ["**/*.swift"])
    /// let dirs = try dir.glob.directories(include: ["*/"])
    /// ```
    public var glob: Glob {
        Glob(self)
    }
}

// MARK: - Shared Implementation

extension File.Directory.Glob {
    /// Matches paths in the directory against pre-compiled glob patterns.
    ///
    /// This is the typed canonical entry point used by all glob variants
    /// accepting `[Glob.Pattern]`. String-based variants parse their inputs
    /// via ``matchPaths(include:excluding:options:)-{String overload}`` and
    /// delegate here.
    @inlinable
    package func matchPaths(
        include: [Glob.Pattern],
        excluding: [Glob.Pattern],
        options: Glob.Options
    ) throws(Glob.Error) -> [Swift.String] {
        var results: [Swift.String] = []
        try Glob.match(
            include: include,
            excluding: excluding,
            in: directory.path.kernelPath,
            options: options
        ) { results.append($0) }

        return results
    }

    /// Parses string patterns into ``Glob/Pattern`` values and delegates to
    /// the typed ``matchPaths(include:excluding:options:)`` overload.
    ///
    /// Convenience for callers that hold raw pattern strings (typically
    /// authored inline at the call site). Callers that already hold parsed
    /// `Glob.Pattern` values SHOULD use the typed overload directly to avoid
    /// re-parsing.
    @inlinable
    package func matchPaths(
        include: [Swift.String],
        excluding: [Swift.String],
        options: Glob.Options
    ) throws(Glob.Error) -> [Swift.String] {
        var includePatterns: [Glob.Pattern] = []
        for pattern in include {
            includePatterns.append(try Glob.Pattern(pattern))
        }

        var excludePatterns: [Glob.Pattern] = []
        for pattern in excluding {
            excludePatterns.append(try Glob.Pattern(pattern))
        }

        return try matchPaths(
            include: includePatterns,
            excluding: excludePatterns,
            options: options
        )
    }
}
