//
//  File.Directory.Temporary.swift
//  swift-file-system
//
//  Test support for temporary directories with automatic cleanup.
//

public import File_System_Primitives
import File_System

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// MARK: - File.Directory.Temporary (namespace)

extension File.Directory {
    /// Namespace for temporary directory operations.
    public enum Temporary {}
}

extension File.Directory.Temporary {
    /// Returns the system temp directory path.
    ///
    /// Uses POSIX `getenv("TMPDIR")`, falling back to "/tmp" if not set.
    public static var system: File.Path {
        get throws {
            let path: String
            if let ptr = getenv("TMPDIR") {
                path = String(cString: ptr)
            } else {
                path = "/tmp"
            }
            return try File.Path(path)
        }
    }

    /// Cleans up leftover temporary directories matching the prefix.
    ///
    /// Useful for CI cleanup when tests may have been interrupted.
    ///
    /// - Parameter prefix: Prefix to match (default: "test").
    /// - Throws: Directory listing errors.
    public static func cleanup(prefix: String = "test") throws {
        let base = try system
        let contents = try File.Directory.Contents.list(at: base)
        let targetPrefix = "\(prefix)-"

        for entry in contents {
            guard let name = String(entry.name) else { continue }
            if name.hasPrefix(targetPrefix) {
                let path = File.Path(base, appending: name)
                try? File.System.Delete.delete(at: path, options: .init(recursive: true))
            }
        }
    }

    /// Generates a random identifier for unique temp paths.
    internal static func randomID() -> String {
        String(Int.random(in: 0..<Int.max), radix: 36)
    }
}

// MARK: - File.Directory.TemporaryScope (wrapper)

extension File.Directory {
    /// Wrapper for scoped temporary directory operations.
    ///
    /// Provides a temporary directory with automatic cleanup when the closure exits.
    ///
    /// ## Example
    /// ```swift
    /// try File.Directory.temporary { dir in
    ///     // dir is a File.Path to a newly created temp directory
    ///     // automatically deleted when the closure exits
    /// }
    /// ```
    public struct TemporaryScope: Sendable {
        /// The prefix for the temp directory name.
        public let prefix: String

        /// Creates a TemporaryScope instance.
        internal init(prefix: String) {
            self.prefix = prefix
        }

        /// Executes a closure with a temporary directory, automatically cleaned up on exit.
        ///
        /// - Parameter body: Closure that receives the temporary directory path.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Path) throws -> T
        ) throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let path = File.Path(base, appending: dirName)

            try File.System.Create.Directory.create(at: path)
            defer { try? File.System.Delete.delete(at: path, options: .init(recursive: true)) }

            return try body(path)
        }

        /// Async variant: executes a closure with a temporary directory, automatically cleaned up on exit.
        ///
        /// - Parameter body: Async closure that receives the temporary directory path.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Path) async throws -> T
        ) async throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let path = File.Path(base, appending: dirName)

            try await File.System.Create.Directory.create(at: path)
            defer { try? File.System.Delete.delete(at: path, options: .init(recursive: true)) }

            return try await body(path)
        }
    }

    /// Creates a temporary directory wrapper with default prefix "test".
    public static var temporary: TemporaryScope {
        TemporaryScope(prefix: "test")
    }

    /// Creates a temporary directory wrapper with custom prefix.
    ///
    /// - Parameter prefix: Prefix for the temp directory name.
    /// - Returns: A `TemporaryScope` wrapper for scoped directory operations.
    public static func temporary(prefix: String) -> TemporaryScope {
        TemporaryScope(prefix: prefix)
    }
}
