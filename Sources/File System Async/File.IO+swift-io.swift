//
//  File.IO+swift-io.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 25/12/2025.
//

public import IO

// MARK: - Handle Types

extension File.IO.Handle {
    /// A unique identifier for a registered file handle.
    ///
    /// This is `IO.Handle.ID` from swift-io.
    public typealias ID = IO.Handle.ID

    /// Errors related to handle operations.
    ///
    /// This is `IO.Handle.Error` from swift-io.
    public typealias Error = IO.Handle.Error
}

// MARK: - Executor Types

extension File.IO.Executor {
    /// Errors specific to the executor.
    ///
    /// This is `IO.Executor.Error` from swift-io.
    public typealias Error = IO.Executor.Error

    /// Transaction-related types.
    public enum Transaction {}

    /// Handle-related types.
    public enum Handle {}
}

extension File.IO.Executor.Handle {
    /// Waiters queue for serializing access to handles.
    ///
    /// This is `IO.Handle.Waiters` from swift-io.
    public typealias Waiters = IO.Handle.Waiters
}

extension File.IO.Executor.Transaction {
    /// Typed error for transaction operations.
    ///
    /// This is `IO.Executor.Transaction.Error` from swift-io.
    public typealias Error = IO.Executor.Transaction.Error
}

// MARK: - Blocking Types

extension File.IO {
    /// Namespace for blocking I/O abstractions.
    public enum Blocking {}
}

extension File.IO.Blocking {
    /// Lane for blocking operations.
    ///
    /// This is `IO.Blocking.Lane` from swift-io.
    public typealias Lane = IO.Blocking.Lane

    /// Deadline for lane acceptance.
    ///
    /// This is `IO.Blocking.Deadline` from swift-io.
    public typealias Deadline = IO.Blocking.Deadline

    /// Infrastructure failures from the lane.
    ///
    /// This is `IO.Blocking.Failure` from swift-io.
    public typealias Failure = IO.Blocking.Failure

    /// Capabilities declared by a lane.
    ///
    /// This is `IO.Blocking.Capabilities` from swift-io.
    public typealias Capabilities = IO.Blocking.Capabilities

    /// Thread pool implementation.
    ///
    /// This is `IO.Blocking.Threads` from swift-io.
    public typealias Threads = IO.Blocking.Threads
}

