//
//  File.System.Write.Streaming.Direct.Strategy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming.Direct {
    /// Strategy for direct (non-atomic) writes.
    public enum Strategy: Sendable {
        /// Fail if destination exists.
        case create

        /// Truncate existing file or create new.
        case truncate
    }
}
