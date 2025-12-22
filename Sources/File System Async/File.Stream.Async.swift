//
//  File.Stream.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Stream {
    /// Internal async streaming implementation.
    ///
    /// Use the static methods instead:
    /// ```swift
    /// for try await chunk in File.Stream.bytes(from: path) {
    ///     process(chunk)
    /// }
    /// ```
    public struct Async: Sendable {
        let io: File.IO.Executor

        /// Creates an async stream API with the given executor.
        public init(io: File.IO.Executor = .default) {
            self.io = io
        }
    }
}
