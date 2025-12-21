//
//  File.Stream+Async.swift
//  swift-file-system
//
//  Async convenience methods for stream operations.
//

extension File.Stream {
    /// Stream file bytes asynchronously.
    ///
    /// ## Example
    /// ```swift
    /// for try await chunk in File.Stream.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The file path.
    ///   - options: Byte streaming options.
    ///   - io: The I/O executor (defaults to `.default`).
    /// - Returns: An async sequence of byte chunks.
    public static func bytes(
        from path: File.Path,
        options: Async.Bytes.Options = .init(),
        io: File.IO.Executor = .default
    ) -> Async.Byte.Sequence {
        Async(io: io).bytes(from: path, options: options)
    }
}
