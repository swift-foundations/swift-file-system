//
//  File.IO.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 22/12/2025.
//

extension File.IO {
    /// Unified error type for File I/O operations.
    ///
    /// Enables typed throws for Swift Embedded compatibility by consolidating
    /// all I/O-related errors into a single enum without existential types.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Handle-related errors.
        case handle(File.IO.Handle.Error)

        /// Executor-related errors.
        case executor(File.IO.Executor.Error)

        /// Thread lane errors.
        case threads(File.IO.Blocking.Threads.Error)

        /// The operation was cancelled.
        case cancelled

        /// A user-provided operation threw an error.
        ///
        /// For Swift Embedded compatibility, the original error is captured
        /// as a description string rather than using existential types.
        case operationFailed(description: String)
    }
}
