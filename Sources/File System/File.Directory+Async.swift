//
//  File.Directory+Async.swift
//  swift-file-system
//
//  Async convenience methods for directory operations.
//

extension File.Directory {
    /// Stream directory entries asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await entry in File.Directory.entries(at: directory) {
    ///     print(entry.name)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - directory: The directory to list.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of directory entries.
    public static func entries(
        at directory: File.Directory,
        io: File.IO.Executor = .default
    ) -> File.Directory.Contents.Async {
        Async(io: io).entries(at: directory)
    }

    /// Lists directory contents asynchronously (non-streaming).
    ///
    /// - Parameters:
    ///   - directory: The directory to list.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: Array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
    public static func contents(
        at directory: File.Directory,
        io: File.IO.Executor = .default
    ) async throws(File.IO.Error<File.Directory.Contents.Error>) -> [File.Directory.Entry] {
        try await Async(io: io).contents(at: directory)
    }

    /// Walk directory tree recursively asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await entry in File.Directory.walk(at: directory) {
    ///     print(entry.path)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - directory: The root directory to walk.
    ///   - options: Walk options.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of walk entries.
    public static func walk(
        at directory: File.Directory,
        options: File.Directory.Walk.Async.Options = .init(),
        io: File.IO.Executor = .default
    ) -> File.Directory.Walk.Async.Sequence {
        Async(io: io).walk(at: directory, options: options)
    }
}
