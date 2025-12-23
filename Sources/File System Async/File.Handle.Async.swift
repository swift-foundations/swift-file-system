//
//  File.Handle.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Handle {
    /// An async-safe file handle wrapper.
    ///
    /// This actor provides async methods for file I/O operations while ensuring
    /// proper resource management and thread safety.
    ///
    /// ## Architecture
    /// The actor does NOT directly own the `File.Handle`. Instead:
    /// - The primitive `File.Handle` lives in the executor's handle store
    /// - This actor holds only a `Handle.ID` (Sendable token)
    /// - All operations go through `io.withHandle(id) { ... }`
    ///
    /// This design solves Swift 6's restrictions on non-Sendable, non-copyable
    /// types in actors by keeping the linear resource in a thread-safe store
    /// and never moving it across async boundaries.
    ///
    /// ## Close Contract
    /// - `close()` must be called explicitly for deterministic release
    /// - If actor deinitializes without `close()`, best-effort cleanup only
    /// - Close errors from deinit cleanup are discarded
    ///
    /// ## Example
    /// ```swift
    /// let handle = try await File.Handle.Async.open(path, mode: .read, io: executor)
    /// let data = try await handle.read(count: 1024)
    /// try await handle.close()
    /// ```
    public actor Async {
        /// The handle ID in the executor's store.
        private let id: File.IO.Handle.ID

        /// The executor that owns the handle store.
        private let io: File.IO.Executor

        /// Whether the handle has been closed.
        private var isClosed: Bool = false

        /// The path this handle was opened for (for diagnostics).
        public nonisolated let path: File.Path

        /// The mode this handle was opened with.
        public nonisolated let mode: File.Handle.Mode

        /// Internal initializer for when handle is already registered.
        internal init(
            id: File.IO.Handle.ID,
            path: File.Path,
            mode: File.Handle.Mode,
            io: File.IO.Executor
        ) {
            self.id = id
            self.path = path
            self.mode = mode
            self.io = io
        }

        deinit {
            // Per plan: debug warning allowed, but no async cleanup
            // The handle remains in the executor's registry until shutdown
            if !isClosed {
                #if DEBUG
                    print(
                        "Warning: File.Handle.Async deallocated without close() for path: \(path). "
                            + "Handle will remain open until executor shutdown."
                    )
                #endif
            }
        }

        // MARK: - Opening

        /// Opens a file and returns an async handle.
        ///
        /// - Parameters:
        ///   - path: The path to the file.
        ///   - mode: The access mode.
        ///   - options: Additional options.
        ///   - io: The executor to use.
        /// - Returns: An async file handle.
        /// - Throws: `File.Handle.Error` on failure.
        public static func open(
            _ path: File.Path,
            mode: File.Handle.Mode,
            options: File.Handle.Options = [],
            io: File.IO.Executor
        ) async throws(File.IO.Error<File.Handle.Error>) -> File.Handle.Async {
            // Use executor's openFile which handles the slot pattern internally
            let id = try await io.openFile(path, mode: mode, options: options)
            return File.Handle.Async(id: id, path: path, mode: mode, io: io)
        }

        // MARK: - Reading

        /// Read into a caller-provided buffer.
        ///
        /// - Parameter destination: The buffer to read into.
        /// - Returns: Number of bytes read (0 at EOF).
        /// - Important: The buffer must remain valid until this call returns.
        public func read(
            into destination: UnsafeMutableRawBufferPointer
        ) async throws(File.IO.Error<File.Handle.Error>) -> Int {
            guard !isClosed else {
                throw .operation(.invalidHandle)
            }

            struct Buffer: @unchecked Swift.Sendable {
                let pointer: UnsafeMutableRawBufferPointer
            }

            // Wrap for Sendable - safe because buffer used synchronously in io.run
            let buffer = Buffer(pointer: destination)
            let body: @Sendable (inout File.Handle) throws(File.Handle.Error) -> Int = { handle in
                try handle.read(into: buffer.pointer)
            }
            return try await io.withHandle(id, body)
        }

        /// Convenience: read into a new array (allocates).
        ///
        /// - Parameter count: Maximum bytes to read.
        /// - Returns: The bytes read.
        public func read(count: Int) async throws(File.IO.Error<File.Handle.Error>) -> [UInt8] {
            guard !isClosed else {
                throw .operation(.invalidHandle)
            }
            let body: @Sendable (inout File.Handle) throws(File.Handle.Error) -> [UInt8] = {
                handle in
                try handle.read(count: count)
            }
            return try await io.withHandle(id, body)
        }

        // MARK: - Writing

        /// Write bytes from an array.
        ///
        /// - Parameter bytes: The bytes to write.
        public func write(_ bytes: [UInt8]) async throws(File.IO.Error<File.Handle.Error>) {
            guard !isClosed else {
                throw .operation(.invalidHandle)
            }
            let body: @Sendable (inout File.Handle) throws(File.Handle.Error) -> Void = { handle in
                try handle.write(bytes.span)
            }
            try await io.withHandle(id, body)
        }

        // MARK: - Seeking

        /// Seek to a position.
        ///
        /// - Parameters:
        ///   - offset: The offset to seek to.
        ///   - origin: The origin for the seek.
        /// - Returns: The new position.
        @discardableResult
        public func seek(
            to offset: Int64,
            from origin: File.Handle.Seek.Origin = .start
        ) async throws(File.IO.Error<File.Handle.Error>) -> Int64 {
            guard !isClosed else {
                throw .operation(.invalidHandle)
            }
            let body: @Sendable (inout File.Handle) throws(File.Handle.Error) -> Int64 = { handle in
                try handle.seek(to: offset, from: origin)
            }
            return try await io.withHandle(id, body)
        }

        // MARK: - Sync

        /// Sync the file to disk.
        public func sync() async throws(File.IO.Error<File.Handle.Error>) {
            guard !isClosed else {
                throw .operation(.invalidHandle)
            }
            let body: @Sendable (inout File.Handle) throws(File.Handle.Error) -> Void = { handle in
                try handle.sync()
            }
            try await io.withHandle(id, body)
        }

        // MARK: - Close

        /// Close the handle.
        ///
        /// - Important: Must be called for deterministic release.
        /// - Note: Safe to call multiple times (idempotent).
        public func close() async throws(File.IO.Error<File.Handle.Error>) {
            guard !isClosed else {
                return  // Already closed - idempotent
            }
            isClosed = true
            try await io.destroyHandle(id)
        }

        /// Whether the handle is still open.
        ///
        /// This queries the executor (source of truth) to determine if the
        /// handle ID refers to a live handle. Returns false if:
        /// - `close()` was called on this wrapper
        /// - The executor shut down and closed the handle
        /// - The handle was destroyed through any other means
        ///
        /// - Note: This is an async property because it queries the executor actor.
        public var isOpen: Bool {
            get async {
                guard !isClosed else { return false }
                return await io.isHandleOpen(id)
            }
        }
    }
}
