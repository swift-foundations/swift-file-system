//
//  File.IO.Executor.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Executor {
    /// Errors specific to the executor.
    public enum Error: Swift.Error, Sendable {
        /// The executor has been shut down.
        case shutdownInProgress

        /// The ID's scope doesn't match this executor.
        case scopeMismatch

        /// The handle or write ID was not found in the registry.
        case handleNotFound

        /// The operation is not valid in the current state.
        case invalidState
    }
}
