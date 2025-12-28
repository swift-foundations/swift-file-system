//
//  File.Directory.Create.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 28/12/2025.
//

// MARK: - Create Namespace

extension File.Directory {
    /// Namespace for directory creation operations.
    ///
    /// Access via the `create` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable (create single directory)
    /// try dir.create()
    ///
    /// // Variant - create parent directories too
    /// try dir.create.recursive()
    /// ```
    public struct Create: Sendable {
        /// The path to create.
        public let path: File.Path

        /// Creates a Create instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }

        // MARK: - callAsFunction (Primary Action)

        /// Creates the directory.
        ///
        /// This is the primary action, accessible via `dir.create()`.
        /// Fails if the parent directory doesn't exist.
        ///
        /// - Parameter options: Create options.
        /// - Throws: `File.System.Create.Directory.Error` on failure.
        @inlinable
        public func callAsFunction(
            options: File.System.Create.Directory.Options = .init()
        ) throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(at: path, options: options)
        }

        /// Creates the directory.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Create.Directory.Error>>` on failure.
        @inlinable
        public func callAsFunction(
            options: File.System.Create.Directory.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Create.Directory.Error>>) {
            try await File.System.Create.Directory.create(at: path, options: options)
        }

        // MARK: - Variants

        /// Creates the directory and any missing parent directories.
        ///
        /// - Parameter options: Create options (createIntermediates is set to true).
        /// - Throws: `File.System.Create.Directory.Error` on failure.
        @inlinable
        public func recursive(
            options: File.System.Create.Directory.Options = .init()
        ) throws(File.System.Create.Directory.Error) {
            var opts = options
            opts.createIntermediates = true
            try File.System.Create.Directory.create(at: path, options: opts)
        }

        /// Creates the directory and any missing parent directories.
        ///
        /// Async variant.
        /// - Throws: `IO.Lifecycle.Error<IO.Error<File.System.Create.Directory.Error>>` on failure.
        @inlinable
        public func recursive(
            options: File.System.Create.Directory.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Create.Directory.Error>>) {
            var opts = options
            opts.createIntermediates = true
            try await File.System.Create.Directory.create(at: path, options: opts)
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to create operations.
    ///
    /// This property returns a callable namespace. Use it directly for the common case,
    /// or access variants via dot syntax:
    /// ```swift
    /// try dir.create()             // create single directory
    /// try dir.create.recursive()   // create with parents
    /// ```
    public var create: Create {
        Create(path)
    }
}
