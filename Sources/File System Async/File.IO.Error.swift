//
//  File.IO.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 22/12/2025.
//

public import IO

extension File.IO {
    /// Generic error type for async File I/O operations.
    ///
    /// This type preserves the specific operation error type while also capturing
    /// I/O infrastructure errors (executor, lane, cancellation).
    ///
    /// ## Usage
    /// Async methods throw `File.IO.Error<SpecificError>` where `SpecificError` is
    /// the error type from the underlying sync primitive:
    /// ```swift
    /// func read() async throws(File.IO.Error<File.System.Read.Full.Error>) -> [UInt8]
    /// ```
    ///
    /// For closure-based APIs where the error type is unknown, use `File.IO.ClosureError`:
    /// ```swift
    /// func withHandle<T>(_ body: ...) async throws(File.IO.Error<File.IO.ClosureError>) -> T
    /// ```
    ///
    /// ## No Equatable Constraint
    /// The Operation type only requires `Error & Sendable` - no `Equatable` constraint.
    /// This enables maximum flexibility. Use `Equatable` in tests where you assert equality.
    public enum Error<Operation: Swift.Error & Sendable>: Swift.Error, Sendable {
        /// The operation-specific error from the underlying primitive.
        case operation(Operation)

        /// Handle-related errors.
        case handle(File.IO.Handle.Error)

        /// Executor-related errors.
        case executor(File.IO.Executor.Error)

        /// Lane infrastructure errors.
        case lane(IO.Blocking.Failure)

        /// The operation was cancelled.
        case cancelled
    }
}

// MARK: - ClosureError

extension File.IO {
    /// Error wrapper for user-provided closure errors.
    ///
    /// Used with `File.IO.Error<File.IO.ClosureError>` when the closure error type
    /// is unknown at compile time. The error description is captured as a string
    /// for Swift Embedded compatibility (avoids existential types).
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await file.open { handle in
    ///         try handle.read(count: 100)
    ///     }
    /// } catch .operation(let closureError) {
    ///     print("Closure failed: \(closureError.description)")
    /// } catch .cancelled {
    ///     print("Cancelled")
    /// }
    /// ```
    public struct ClosureError: Swift.Error, Sendable, Equatable {
        /// A description of the original error.
        public let description: String

        /// Creates a closure error from any typed error.
        /// Generic version - no existentials.
        public init<E: Swift.Error>(_ error: E) {
            self.description = String(describing: error)
        }

        /// Creates a closure error from a description.
        public init(description: String) {
            self.description = description
        }
    }
}

// MARK: - Mapping

extension File.IO.Error {
    /// Maps the operation error to a different type.
    ///
    /// Non-operation cases are preserved as-is.
    public func mapOperation<NewOperation: Swift.Error & Sendable>(
        _ transform: (Operation) -> NewOperation
    ) -> File.IO.Error<NewOperation> {
        switch self {
        case .operation(let op):
            return .operation(transform(op))
        case .handle(let error):
            return .handle(error)
        case .executor(let error):
            return .executor(error)
        case .lane(let failure):
            return .lane(failure)
        case .cancelled:
            return .cancelled
        }
    }
}

// MARK: - CustomStringConvertible

extension File.IO.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .operation(let error):
            return "Operation error: \(error)"
        case .handle(let error):
            return "Handle error: \(error)"
        case .executor(let error):
            return "Executor error: \(error)"
        case .lane(let failure):
            return "Lane failure: \(failure)"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}

extension File.IO.ClosureError: CustomStringConvertible {
    // Uses the stored description
}
