//
//  File.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 22/12/2025.
//

// MARK: - Unified Error Type

extension File {
    /// Unified error type for File operations that may fail from multiple sources.
    ///
    /// This type is used only for closure-based APIs (like `File.open { ... }`) where
    /// errors can come from both the file operation itself and the user's closure.
    /// For simple operations with a single error source, the specific error type
    /// is used directly (e.g., `throws(File.System.Read.Full.Error)`).
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try file.open.read { handle in
    ///         try handle.read(count: 100)
    ///     }
    /// } catch .handle(let handleError) {
    ///     // Handle file operation error
    /// } catch .operation(let description) {
    ///     // Handle closure error (captured as description)
    /// }
    /// ```
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Handle operation failed (open, close, seek, read, write, etc.)
        case handle(File.Handle.Error)

        /// User-provided closure threw an error.
        ///
        /// The error description is captured as a string for Swift Embedded
        /// compatibility (avoids existential types like `any Error`).
        case operation(description: String)
    }
}

// MARK: - CustomStringConvertible

extension File.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .handle(let error):
            return "File handle error: \(error)"
        case .operation(let description):
            return "Operation error: \(description)"
        }
    }
}
