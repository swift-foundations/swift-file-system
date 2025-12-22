//
//  File.Directory.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory {
    /// Internal async directory implementation.
    ///
    /// Use the static methods instead:
    /// ```swift
    /// for try await entry in File.Directory.entries(at: path) {
    ///     print(entry.name)
    /// }
    /// ```
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async directory API with the given executor.
        public init(io: File.IO.Executor = .default) {
            self.io = io
        }

        /// Lists directory contents (non-streaming).
        public func contents(at path: File.Path) async throws(File.IO.Error<File.Directory.Contents.Error>) -> [File.Directory.Entry] {
            let operation: @Sendable () throws(File.Directory.Contents.Error) -> [File.Directory.Entry] = {
                try File.Directory.Contents.list(at: path)
            }
            return try await io.run(operation)
        }
    }
}
