//
//  File.Directory.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import IO

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
        let fs: File.System.Async

        /// Creates an async directory API with the given file system.
        public init(fs: File.System.Async = .async) {
            self.fs = fs
        }

        /// Lists directory contents (non-streaming).
        public func contents(
            at directory: File.Directory
        ) async throws(IO.Lifecycle.Error<IO.Error<File.Directory.Contents.Error>>) -> [File.Directory.Entry] {
            let operation: @Sendable () throws(File.Directory.Contents.Error) -> [File.Directory.Entry] = {
                try File.Directory.Contents.list(at: directory)
            }
            return try await fs.run(operation)
        }
    }
}
