//
//  File.Directory.Temporary.swift
//  swift-file-system
//
//  Test support for temporary directories with automatic cleanup.
//

import File_System
public import File_System_Core

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
    #if os(Windows)
        /// Gets an environment variable using Windows API.
        private static func getEnvironmentVariable(_ name: Swift.String) -> String? {
            name.withCString(encodedAs: UTF16.self) { wName in
                // First call to get required buffer size
                let requiredSize = GetEnvironmentVariableW(wName, nil, 0)
                guard requiredSize > 0 else { return nil }

                // Allocate buffer and get the value
                var buffer = [WCHAR](repeating: 0, count: Int(requiredSize))
                let written = GetEnvironmentVariableW(wName, &buffer, requiredSize)
                guard written > 0 && written < requiredSize else { return nil }

                return String(decodingCString: buffer, as: UTF16.self)
            }
        }
    #endif

    /// Returns the system temp directory path.
    ///
    /// Uses platform-appropriate environment variables:
    /// - Unix: `TMPDIR`, falling back to "/tmp"
    /// - Windows: `TEMP` or `TMP`, falling back to "C:\Temp"
    public static var system: File.Directory {
        get throws {
            let path: Swift.String
            #if os(Windows)
                if let temp = getEnvironmentVariable("TEMP") {
                    path = temp
                } else if let tmp = getEnvironmentVariable("TMP") {
                    path = tmp
                } else {
                    path = "C:\\Temp"
                }
            #else
                if let ptr = unsafe getenv("TMPDIR") {
                    path = unsafe Swift.String(cString: ptr)
                } else {
                    path = "/tmp"
                }
            #endif
            return try File.Directory(validating: path)
        }
    }

    /// Cleans up leftover temporary directories matching the prefix.
    ///
    /// Useful for CI cleanup when tests may have been interrupted.
    ///
    /// - Parameter prefix: Prefix to match (default: "test").
    /// - Throws: Directory listing errors.
    public static func cleanup(prefix: Swift.String = "test") throws {
        let base = try system
        let contents = try File.Directory.Contents.list(at: base)
        let targetPrefix = "\(prefix)-"

        for entry in contents {
            guard let name = Swift.String(entry.name) else { continue }
            if name.hasPrefix(targetPrefix), let component = try? File.Path.Component(name) {
                let path = base.path / component
                try? File.System.Delete.delete(at: path, recursive: true)
            }
        }
    }

    /// Generates a random identifier for unique temp paths.
    internal static func randomID() -> Swift.String {
        Swift.String(Int.random(in: (0..<Int.max)), radix: 36)
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
        public let prefix: Swift.String

        /// Creates a Scope instance.
        ///
        /// - Parameter prefix: Prefix for the temp directory name (default: "test").
        public init(prefix: Swift.String = "test") {
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
            let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
            let path = base.path / dirName

            try File.System.Create.Directory.create(at: path)
            defer { try? File.System.Delete.delete(at: path, recursive: true) }

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
            let dirName = try File.Path.Component("\(prefix)-\(File.Directory.Temporary.randomID())")
            let path = base.path / dirName

            try File.System.Create.Directory.create(at: path)

            do {
                let value = try await body(File.Directory(path))
                try? File.System.Delete.delete(at: path, recursive: true)
                return value
            } catch {
                try? File.System.Delete.delete(at: path, recursive: true)
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
