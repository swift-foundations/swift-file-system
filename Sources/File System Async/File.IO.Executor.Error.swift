//
//  File.IO.Executor.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// Errors specific to the executor.
    public enum ExecutorError: Error, Sendable {
        /// The executor has been shut down.
        case shutdownInProgress
    }
}
