//
//  File.Stream.Async.Options.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Stream.Async {
    /// Options for async byte streaming.
    public struct Options: Sendable {
        /// Size of each chunk in bytes.
        public var chunkSize: Int

        /// Creates byte streaming options.
        ///
        /// - Parameter chunkSize: Chunk size in bytes (default: 64KB).
        public init(chunkSize: Int = 64 * 1024) {
            self.chunkSize = max(1, chunkSize)
        }
    }
}
