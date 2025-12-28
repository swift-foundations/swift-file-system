//
//  File.System.Read.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.System.Read {
    /// Async streaming read implementation.
    ///
    /// Use the static methods instead:
    /// ```swift
    /// for try await chunk in File.System.Read.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    public struct Async: Sendable {
        let fs: File.System.Async

        /// Creates an async read API with the given file system.
        public init(fs: File.System.Async = .async) {
            self.fs = fs
        }
    }
}
