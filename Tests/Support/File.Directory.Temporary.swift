//
//  File.Directory.Temporary.swift
//  swift-file-system
//
//  Test support for temporary directories with automatic cleanup.
//

import File_System
public import File_System_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import ucrt
    import WinSDK
#endif

// MARK: - File.Directory.Temporary (namespace)

extension File.Directory {
    /// Namespace for temporary directory operations.
    public enum Temporary {}
}

extension File.Directory.Temporary {
    /// Returns the system temp directory path.
    ///
    /// Uses platform-appropriate environment variables:
    /// - Unix: `TMPDIR`, falling back to "/tmp"
    /// - Windows: `TEMP` or `TMP`, falling back to "C:\Temp"
    public static var system: File.Directory {
        get throws {
            let path: String
            #if os(Windows)
                if let ptr = getenv("TEMP") {
                    path = String(cString: ptr)
                } else if let ptr = getenv("TMP") {
                    path = String(cString: ptr)
                } else {
                    path = "C:\\Temp"
                }
            #else
                if let ptr = getenv("TMPDIR") {
                    path = String(cString: ptr)
                } else {
                    path = "/tmp"
                }
            #endif
            return try File.Directory(path)
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
                let path = File.Path(base.path, appending: name)
                try? File.System.Delete.delete(at: path, options: .init(recursive: true))
            }
        }
    }

    /// Generates a random identifier for unique temp paths.
    internal static func randomID() -> String {
        String(Int.random(in: 0..<Int.max), radix: 36)
    }
}

// MARK: - File.Directory.Temporary.Scope (wrapper)

extension File.Directory.Temporary {
    /// Wrapper for scoped temporary directory operations.
    ///
    /// Provides a temporary directory with automatic cleanup when the closure exits.
    ///
    /// ## Example
    /// ```swift
    /// try File.Directory.temporary { dir in
    ///     // dir is a File.Directory wrapping a newly created temp directory
    ///     // automatically deleted when the closure exits
    ///     let file = dir[file: "test.txt"]
    ///     try file.write("hello")
    /// }
    /// ```
    public struct Scope: Sendable {
        /// The prefix for the temp directory name.
        public let prefix: String

        /// Creates a Scope instance.
        ///
        /// - Parameter prefix: Prefix for the temp directory name (default: "test").
        public init(prefix: String = "test") {
            self.prefix = prefix
        }

        /// Executes a closure with a temporary directory, automatically cleaned up on exit.
        ///
        /// - Parameter body: Closure that receives the temporary directory.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Directory) throws -> T
        ) throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let path = File.Path(base, appending: dirName)

            try File.System.Create.Directory.create(at: path)
            defer { try? File.System.Delete.delete(at: path, options: .init(recursive: true)) }

            return try body(File.Directory(path))
        }

        /// Async variant: executes a closure with a temporary directory, automatically cleaned up on exit.
        ///
        /// - Parameter body: Async closure that receives the temporary directory.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Directory) async throws -> T
        ) async throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let path = File.Path(base, appending: dirName)

            try await File.System.Create.Directory.create(at: path)

            do {
                let value = try await body(File.Directory(path))
                try? await File.System.Delete.delete(at: path, options: .init(recursive: true))
                return value
            } catch {
                try? await File.System.Delete.delete(at: path, options: .init(recursive: true))
                throw error
            }
        }
    }

}

// MARK: - File.Directory convenience

extension File.Directory {
    /// Creates a temporary directory wrapper with default prefix "test".
    ///
    /// ## Example
    /// ```swift
    /// try File.Directory.temporary { dir in
    ///     // dir is a File.Directory wrapping a newly created temp directory
    ///     // automatically deleted when the closure exits
    ///     let file = dir[file: "test.txt"]
    ///     try file.write("hello")
    /// }
    /// ```
    ///
    /// For custom prefix, use `File.Directory.Temporary.Scope(prefix:)` directly.
    public static var temporary: Temporary.Scope {
        Temporary.Scope()
    }
}
