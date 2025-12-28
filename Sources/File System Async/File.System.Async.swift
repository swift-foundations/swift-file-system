//
//  File.System.Async.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 27/12/2025.
//

@_exported import IO

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

extension File.System {
    /// Async file system operations using IO.Blocking.Lane.
    ///
    /// This is the canonical async entry point. It owns the lane and pools,
    /// and exposes IO types directly (no wrappers).
    ///
    /// ## Design
    /// - **One lane**: All blocking syscalls execute on `IO.Blocking.Lane` (internal)
    /// - **Three pools**: `work` for one-shot operations, `handles` for file handles, `writes` for streaming
    /// - **One handle ID**: All handles are `IO.Handle.ID`
    ///
    /// ## Lifecycle
    /// - **The `.async` default does not require shutdown** (process-scoped)
    /// - Custom instances must call `shutdown()` when done
    ///
    /// ## Example
    /// ```swift
    /// // Using process-scoped default
    /// let data = try await File.System.async.read(path)
    ///
    /// // Using custom instance
    /// let fs = File.System.Async(IO.Blocking.Threads.Options(workers: 4))
    /// defer { Task { await fs.shutdown() } }
    /// let data = try await fs.read(path)
    /// ```
    public struct Async: Sendable {
        /// Minimal resource for one-shot blocking operations.
        public struct Work: ~Copyable {}

        /// Pool for one-shot blocking operations.
        public let work: IO.Executor.Pool<Work>

        /// Pool for file handle resources.
        public let handles: IO.Executor.Pool<File.Handle>

        /// Pool for streaming write resources.
        public let writes: IO.Executor.Pool<File.System.Write.Async>

        /// Lane used only for pool construction (private).
        private let lane: IO.Blocking.Lane

        /// Whether this instance owns its lane and can shut it down.
        private let ownsLane: Bool

        /// Whether this is the shared default instance (does not require shutdown).
        private let isDefault: Bool

        // MARK: - Initializers

        /// Creates an async file system with an external lane.
        ///
        /// The instance does NOT own this lane and will NOT shut it down.
        /// The caller is responsible for lane lifecycle management.
        ///
        /// - Parameter lane: The lane for executing blocking operations.
        public init(lane: IO.Blocking.Lane) {
            self.lane = lane
            self.ownsLane = false
            self.isDefault = false

            self.work = IO.Executor.Pool<Work>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .drop()
            )

            self.handles = IO.Executor.Pool<File.Handle>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { handle in
                    try? handle.close()
                }
            )

            self.writes = IO.Executor.Pool<File.System.Write.Async>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { resource in
                    #if os(Windows)
                        File.System.Write.Streaming.Windows.cleanup(resource.context)
                    #else
                        File.System.Write.Streaming.POSIX.cleanup(resource.context)
                    #endif
                }
            )
        }

        /// Creates an async file system with a new Threads lane.
        ///
        /// The instance owns this lane and will shut it down when `shutdown()` is called.
        ///
        /// - Parameter options: Options for the Threads lane.
        public init(_ options: IO.Blocking.Threads.Options = .init()) {
            let lane = IO.Blocking.Lane.threads(options)
            self.lane = lane
            self.ownsLane = true
            self.isDefault = false

            self.work = IO.Executor.Pool<Work>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .drop()
            )

            self.handles = IO.Executor.Pool<File.Handle>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { handle in
                    try? handle.close()
                }
            )

            self.writes = IO.Executor.Pool<File.System.Write.Async>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { resource in
                    #if os(Windows)
                        File.System.Write.Streaming.Windows.cleanup(resource.context)
                    #else
                        File.System.Write.Streaming.POSIX.cleanup(resource.context)
                    #endif
                }
            )
        }

        /// Private initializer for the default instance.
        private init(default options: IO.Blocking.Threads.Options) {
            let lane = IO.Blocking.Lane.threads(options)
            self.lane = lane
            self.ownsLane = false  // Default instance never shuts down lane
            self.isDefault = true

            self.work = IO.Executor.Pool<Work>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .drop()
            )

            self.handles = IO.Executor.Pool<File.Handle>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { handle in
                    try? handle.close()
                }
            )

            self.writes = IO.Executor.Pool<File.System.Write.Async>(
                lane: lane,
                handleWaitersLimit: 64,
                teardown: .onLane(lane) { resource in
                    #if os(Windows)
                        File.System.Write.Streaming.Windows.cleanup(resource.context)
                    #else
                        File.System.Write.Streaming.POSIX.cleanup(resource.context)
                    #endif
                }
            )
        }

        // MARK: - Process-scoped Default

        /// The shared default async file system for common use cases.
        ///
        /// This instance is lazily initialized and process-scoped:
        /// - Uses a `Threads` lane with default options
        /// - Does **not** require `shutdown()` (calling it is a no-op)
        /// - Suitable for the 80% case where you need simple async I/O
        ///
        /// For advanced use cases (custom lane, explicit lifecycle management),
        /// create your own instance.
        public static let `async` = Async(default: .init())

        // MARK: - Shutdown

        /// Shut down pools and lane.
        ///
        /// - For `.async` default: no-op (process-scoped)
        /// - For explicit lane: shuts down pools only
        /// - For owned lane: shuts down pools and lane
        public func shutdown() async {
            // Default instance is process-scoped - shutdown is a no-op
            guard !isDefault else { return }

            // Shutdown pools
            await writes.shutdown()
            await handles.shutdown()
            await work.shutdown()

            // Shutdown lane only if we own it
            if ownsLane {
                await lane.shutdown()
            }
        }
    }
}

// MARK: - One-shot Operations

extension File.System.Async {
    /// Execute a blocking operation on the work pool.
    ///
    /// This is the low-level primitive. For file operations, prefer the
    /// higher-level methods like `read`, `write`, `stat`.
    ///
    /// - Parameter operation: The blocking operation to execute.
    /// - Returns: The result of the operation.
    /// - Throws: `IO.Lifecycle.Error<IO.Error<E>>` on failure.
    public func run<T: Sendable, E: Swift.Error & Sendable>(
        _ operation: @Sendable @escaping () throws(E) -> T
    ) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T {
        try await work.run(operation)
    }
}

// MARK: - Handle Operations

extension File.System.Async {
    /// Open a file and return its handle ID.
    ///
    /// - Parameters:
    ///   - path: The path to the file.
    ///   - mode: The access mode.
    ///   - options: Additional options.
    /// - Returns: An `IO.Handle.ID` for subsequent operations.
    public func open(
        _ path: File.Path,
        mode: File.Handle.Mode,
        options: File.Handle.Options = [.closeOnExec]
    ) async throws(IO.Lifecycle.Error<IO.Error<File.Handle.Error>>) -> IO.Handle.ID {
        try await handles.register {
            () throws(File.Handle.Error) -> File.Handle in
            try File.Handle.open(path, mode: mode, options: options)
        }
    }

    /// Close a file handle.
    ///
    /// - Parameter id: The handle ID from `open`.
    public func close(_ id: IO.Handle.ID) async throws(IO.Handle.Error) {
        try await handles.destroy(id)
    }

    /// Execute a transaction with exclusive handle access.
    ///
    /// - Parameters:
    ///   - id: The handle ID.
    ///   - body: Closure receiving inout access to the handle.
    /// - Returns: The result of the closure.
    public func transaction<T: Sendable, E: Swift.Error & Sendable>(
        _ id: IO.Handle.ID,
        _ body: @Sendable @escaping (inout File.Handle) throws(E) -> T
    ) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T {
        try await handles.withHandle(id, body)
    }
}

// MARK: - Streaming Write Operations

extension File.System.Async {
    /// Namespace for streaming write operations.
    public var streaming: Streaming { Streaming(fs: self) }

    /// Streaming write operations namespace.
    ///
    /// Provides multi-phase streaming writes with backpressure and cancellation support.
    ///
    /// ## Usage
    /// ```swift
    /// let id = try await fs.streaming.open(to: path)
    /// try await fs.streaming.write(chunk: bytes, to: id)
    /// try await fs.streaming.commit(id)
    /// ```
    public struct Streaming: Sendable {
        let fs: File.System.Async

        /// Open a streaming write to the specified path.
        ///
        /// Returns an ID for subsequent `write(chunk:to:)`, `commit(_:)`,
        /// and `abort(_:)` calls.
        ///
        /// - Parameters:
        ///   - path: The destination path.
        ///   - options: Streaming write options.
        /// - Returns: An `IO.Handle.ID` for subsequent operations.
        public func open(
            to path: File.Path,
            options: File.System.Write.Streaming.Options = .init()
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>) -> IO.Handle.ID {
            let pathString = String(path)

            return try await fs.writes.register {
                () throws(File.System.Write.Streaming.Error) -> File.System.Write.Async in
                #if os(Windows)
                    let context = try File.System.Write.Streaming.Windows.open(path: pathString, options: options)
                #else
                    let context = try File.System.Write.Streaming.POSIX.open(path: pathString, options: options)
                #endif
                return File.System.Write.Async(context: context, path: path, options: options)
            }
        }

        /// Write a chunk of bytes to a streaming write.
        ///
        /// Chunks are written in order. Concurrent calls serialize automatically.
        ///
        /// - Parameters:
        ///   - bytes: The bytes to write.
        ///   - id: The write handle ID from `open(to:options:)`.
        public func write(
            chunk bytes: [UInt8],
            to id: IO.Handle.ID
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>) {
            try await fs.writes.withHandle(id) {
                (resource: inout File.System.Write.Async) throws(File.System.Write.Streaming.Error) in
                guard resource.state == .open else {
                    throw File.System.Write.Streaming.Error.invalidState
                }
                #if os(Windows)
                    try File.System.Write.Streaming.Windows.write(chunk: bytes.span, to: resource.context)
                #else
                    try File.System.Write.Streaming.POSIX.write(chunk: bytes.span, to: resource.context)
                #endif
            }
        }

        /// Commit a streaming write, making it durable.
        ///
        /// After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `open(to:options:)`.
        public func commit(
            _ id: IO.Handle.ID
        ) async throws(IO.Lifecycle.Error<IO.Error<File.System.Write.Streaming.Error>>) {
            try await fs.writes.withHandle(id) {
                (resource: inout File.System.Write.Async) throws(File.System.Write.Streaming.Error) in
                guard resource.state == .open else {
                    throw File.System.Write.Streaming.Error.invalidState
                }
                resource.state = .committing
                #if os(Windows)
                    try File.System.Write.Streaming.Windows.commit(resource.context)
                #else
                    try File.System.Write.Streaming.POSIX.commit(resource.context)
                #endif
                resource.state = .closed
            }
            try? await fs.writes.destroy(id)
        }

        /// Abort a streaming write, cleaning up the temporary file.
        ///
        /// This is idempotent. After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `open(to:options:)`.
        public func abort(_ id: IO.Handle.ID) async {
            do {
                try await fs.writes.withHandle(id) {
                    (resource: inout File.System.Write.Async) in
                    resource.state = .aborting
                }
            } catch {
                // Transaction failed - resource may already be gone
            }

            try? await fs.writes.destroy(id)
        }
    }
}
