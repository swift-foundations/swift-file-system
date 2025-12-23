//
//  File.Temporary.swift
//  swift-file-system
//
//  Test support for temporary files with automatic cleanup.
//

import File_System
public import File_System_Primitives

extension File {
    /// Wrapper for scoped temporary file operations.
    ///
    /// Provides a temporary file path with automatic cleanup when the closure exits.
    /// The file is not created - the caller is responsible for writing to it.
    ///
    /// ## Example
    /// ```swift
    /// try File.temporary(extension: "pdf") { path in
    ///     // path is a File.Path like /tmp/test-abc123/test-xyz789.pdf
    ///     try renderer.write(to: path)
    ///     // automatically deleted when the closure exits
    /// }
    /// ```
    public struct Temporary: Sendable {
        /// The file extension (e.g., "pdf", "txt").
        public let ext: String

        /// The prefix for the temp file name.
        public let prefix: String

        /// Creates a Temporary instance.
        internal init(extension ext: String, prefix: String) {
            self.ext = ext
            self.prefix = prefix
        }

        /// Executes a closure with a temporary file path, automatically cleaned up on exit.
        ///
        /// - Parameter body: Closure that receives the temporary file path.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Path) throws -> T
        ) throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let dirPath = File.Path(base, appending: dirName)

            try File.System.Create.Directory.create(at: dirPath)
            defer { try? File.System.Delete.delete(at: dirPath, options: .init(recursive: true)) }

            let fileName = "\(prefix)-\(File.Directory.Temporary.randomID()).\(ext)"
            let filePath = File.Path(dirPath, appending: fileName)

            return try body(filePath)
        }

        /// Async variant: executes a closure with a temporary file path, automatically cleaned up on exit.
        ///
        /// - Parameter body: Async closure that receives the temporary file path.
        /// - Returns: The value returned by the closure.
        /// - Throws: Any error from directory creation or the closure.
        @discardableResult
        public func callAsFunction<T>(
            _ body: (File.Path) async throws -> T
        ) async throws -> T {
            let base = try File.Directory.Temporary.system
            let dirName = "\(prefix)-\(File.Directory.Temporary.randomID())"
            let dirPath = File.Path(base, appending: dirName)

            try await File.System.Create.Directory.create(at: dirPath)
            defer { try? File.System.Delete.delete(at: dirPath, options: .init(recursive: true)) }

            let fileName = "\(prefix)-\(File.Directory.Temporary.randomID()).\(ext)"
            let filePath = File.Path(dirPath, appending: fileName)

            return try await body(filePath)
        }
    }

    /// Creates a temporary file wrapper.
    ///
    /// - Parameters:
    ///   - ext: File extension (e.g., "pdf", "txt").
    ///   - prefix: Prefix for the temp file name (default: "test").
    /// - Returns: A `Temporary` wrapper for scoped file operations.
    public static func temporary(
        extension ext: String,
        prefix: String = "test"
    ) -> Temporary {
        Temporary(extension: ext, prefix: prefix)
    }
}
