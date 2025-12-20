//
//  File.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

/// A file reference providing convenient access to filesystem operations.
///
/// `File` wraps a path and provides ergonomic methods that
/// delegate to `File.System.*` primitives. It is Hashable and Sendable.
///
/// ## Modern Swift Features
/// - ExpressibleByStringLiteral for ergonomic initialization
/// - Async variants for concurrent contexts
/// - Throwing getters for metadata properties
///
/// ## Example
/// ```swift
/// let file: File = "/tmp/data.txt"
/// let contents = try file.read()
/// try file.write("Hello!")
///
/// // Property-style stat checks
/// if file.exists && file.isFile {
///     print("Size: \(try file.size)")
/// }
/// ```
public struct File: Hashable, Sendable {
    /// The underlying file path.
    public let path: File.Path

    // MARK: - Initializers

    /// Creates a file from a path.
    ///
    /// - Parameter path: The file path.
    public init(_ path: File.Path) {
        self.path = path
    }
}
