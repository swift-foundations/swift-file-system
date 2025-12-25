//
//  File.IO.Executor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import IO

extension File.IO {
    /// The executor for async file I/O operations.
    ///
    /// ## Design
    /// The executor is a thin wrapper over `IO.Executor.Pool<File.Handle>` that adds:
    /// - File-specific teardown (closing file descriptors on the lane)
    /// - Streaming write operations (file-specific functionality)
    ///
    /// Most handle management (registration, transactions, waiters) is delegated
    /// to the underlying pool from swift-io.
    ///
    /// ## Lifecycle
    /// - **The `.default` executor does not require shutdown** (process-scoped)
    /// - Custom executors must call `shutdown()` when done
    ///
    /// ## Handle Management
    /// The executor owns all file handles in an actor-isolated registry.
    /// Handles are accessed via transactions that provide exclusive access.
    /// Only IDs cross await boundaries; handles never escape the actor.
    public actor Executor {
        /// The underlying pool from swift-io.
        private let pool: IO.Executor.Pool<File.Handle>

        /// Whether this is the shared default executor (does not require shutdown).
        private let isDefaultExecutor: Bool

        /// Actor-owned streaming write registry.
        /// Each entry holds a platform write context plus state and waiters.
        private var writes: [File.IO.Write.Handle.ID: Write.Entry] = [:]

        /// Counter for generating unique write IDs.
        private var nextWriteRawID: UInt64 = 0

        // MARK: - Shared Default Executor

        /// The shared default executor for common use cases.
        ///
        /// This executor is lazily initialized and process-scoped:
        /// - Uses a `Threads` lane with default options
        /// - Does **not** require `shutdown()` (calling it is a no-op)
        /// - Suitable for the 80% case where you need simple async I/O
        ///
        /// For advanced use cases (custom lane, explicit lifecycle management),
        /// create your own executor instance.
        ///
        /// ## Example
        /// ```swift
        /// for try await entry in File.Directory.Async(io: .default).entries(at: path) {
        ///     print(entry.name)
        /// }
        /// ```
        public static let `default` = Executor(default: IO.Blocking.Threads.Options())

        // MARK: - Initializers

        /// Creates an executor with the given lane.
        ///
        /// Executors created with this initializer **must** be shut down
        /// when no longer needed using `shutdown()`.
        ///
        /// - Parameter lane: The lane for executing blocking operations.
        public init(lane: IO.Blocking.Lane) {
            // Create pool with file-specific teardown that closes on the lane
            self.pool = IO.Executor.Pool<File.Handle>(
                lane: lane,
                teardown: { address in
                    // Close the file descriptor on the lane (blocking I/O)
                    // Uses consume(at:) to move resource out and close it
                    _ = try? await lane.run(deadline: nil) {
                        IO.Executor.Slot.Container<File.Handle>.consume(at: address.pointer) {
                            try? $0.close()
                        }
                    }
                }
            )
            self.isDefaultExecutor = false
        }

        /// Creates an executor with default Threads lane options.
        ///
        /// This is a convenience initializer equivalent to:
        /// ```swift
        /// Executor(lane: .threads(options))
        /// ```
        ///
        /// - Parameter options: Options for the Threads lane.
        public init(_ options: IO.Blocking.Threads.Options = .init()) {
            let lane = IO.Blocking.Lane.threads(options)
            self.pool = IO.Executor.Pool<File.Handle>(
                lane: lane,
                policy: options.policy,
                teardown: { address in
                    _ = try? await lane.run(deadline: nil) {
                        IO.Executor.Slot.Container<File.Handle>.consume(at: address.pointer) {
                            try? $0.close()
                        }
                    }
                }
            )
            self.isDefaultExecutor = false
        }

        /// Private initializer for the default executor.
        private init(default options: IO.Blocking.Threads.Options) {
            let lane = IO.Blocking.Lane.threads(options)
            self.pool = IO.Executor.Pool<File.Handle>(
                lane: lane,
                policy: options.policy,
                teardown: { address in
                    _ = try? await lane.run(deadline: nil) {
                        IO.Executor.Slot.Container<File.Handle>.consume(at: address.pointer) {
                            try? $0.close()
                        }
                    }
                }
            )
            self.isDefaultExecutor = true
        }

        // MARK: - Pool Delegation

        /// The lane for executing blocking operations.
        ///
        /// This is `nonisolated` because `Lane` is Sendable and immutable after init.
        public nonisolated var lane: IO.Blocking.Lane {
            pool.lane
        }

        /// Unique scope identifier for this executor instance.
        public nonisolated var scope: UInt64 {
            pool.scope
        }

        // MARK: - Execution

        /// Execute a blocking operation on the lane with typed throws.
        ///
        /// This method preserves the operation's specific error type while also
        /// capturing I/O infrastructure errors in `File.IO.Error<E>`.
        ///
        /// ## Cancellation Semantics
        /// - Cancellation before acceptance → `.cancelled`
        /// - Cancellation after acceptance → operation completes, then `.cancelled`
        ///
        /// - Parameter operation: The blocking operation to execute.
        /// - Returns: The result of the operation.
        /// - Throws: `File.IO.Error<E>` with the specific operation error or infrastructure error.
        public func run<T: Sendable, E: Swift.Error & Sendable>(
            _ operation: @Sendable @escaping () throws(E) -> T
        ) async throws(File.IO.Error<E>) -> T {
            do {
                return try await pool.run(operation)
            } catch {
                throw _mapIOError(error)
            }
        }

        // MARK: - Shutdown

        /// Shut down the executor.
        ///
        /// 1. Marks executor as shut down (rejects new `run()` calls)
        /// 2. Tears down all file handles deterministically (closes on lane)
        /// 3. Cleans up streaming writes
        /// 4. Shuts down the lane
        ///
        /// - Note: Calling `shutdown()` on the `.default` executor is a no-op.
        ///   The default executor is process-scoped and does not require shutdown.
        public func shutdown() async {
            // Default executor is process-scoped - shutdown is a no-op
            guard !isDefaultExecutor else { return }

            // Clean up streaming writes
            // Snapshot before iterating to avoid "mutated while being enumerated" trap
            let writeEntries = Array(writes)
            writes.removeAll(keepingCapacity: false)

            for (_, entry) in writeEntries {
                if let ctx = entry.context {
                    _ = try? await lane.run(deadline: nil) {
                        #if os(Windows)
                            WindowsStreaming.cleanup(ctx)
                        #else
                            POSIXStreaming.cleanup(ctx)
                        #endif
                    }
                }
            }

            // Shutdown the pool (handles teardown via closure)
            await pool.shutdown()
        }

        // MARK: - Handle Management

        /// Open a file and register it, returning the handle ID.
        ///
        /// This uses the pool's factory registration pattern: the file is opened
        /// on the lane (blocking I/O) and registered atomically within the pool
        /// actor context. No cross-actor File.Handle transfer occurs.
        ///
        /// - Parameters:
        ///   - path: The path to the file.
        ///   - mode: The access mode.
        ///   - options: Additional options.
        /// - Returns: A handle ID for future operations.
        /// - Throws: `File.IO.Error<File.Handle.Error>` on failure.
        package func openFile(
            _ path: File.Path,
            mode: File.Handle.Mode,
            options: File.Handle.Options = [.closeOnExec]
        ) async throws(File.IO.Error<File.Handle.Error>) -> File.IO.Handle.ID {
            // Use pool's factory registration - file is opened and registered
            // atomically within the pool actor, no cross-actor transfer needed
            do throws(IO.Error<File.Handle.Error>) {
                return try await pool.register { () throws(File.Handle.Error) -> File.Handle in
                    try File.Handle.open(path, mode: mode, options: options)
                }
            } catch {
                throw _mapIOError(error)
            }
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `File.IO.Error<E>` on failure.
        package func withHandle<T: Sendable, E: Swift.Error & Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws(E) -> T
        ) async throws(File.IO.Error<E>) -> T {
            do {
                return try await pool.withHandle(id, body)
            } catch {
                throw _mapIOError(error)
            }
        }

        /// Execute a transaction with exclusive handle access and typed errors.
        package func transaction<T: Sendable, E: Swift.Error & Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws(E) -> T
        ) async throws(File.IO.Executor.Transaction.Error<E>) -> T {
            do {
                return try await pool.transaction(id, body)
            } catch {
                throw _mapTransactionError(error)
            }
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Note: Idempotent for handles that were already destroyed.
        package func destroyHandle(_ id: File.IO.Handle.ID) async throws(File.IO.Error<File.Handle.Error>) {
            do {
                try await pool.destroy(id)
            } catch {
                throw .handle(error)
            }
        }

        /// Check if a handle ID is currently valid.
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle exists and is not destroyed.
        package func isHandleValid(_ id: File.IO.Handle.ID) async -> Bool {
            await pool.isValid(id)
        }

        /// Check if a handle ID refers to an open handle.
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle is logically open.
        package func isHandleOpen(_ id: File.IO.Handle.ID) async -> Bool {
            await pool.isOpen(id)
        }

        // MARK: - Streaming Write Operations

        /// Opens a streaming write to the specified path.
        ///
        /// Returns an ID that can be used for subsequent `writeChunk`, `commitWrite`,
        /// and `abortWrite` calls. The write context lives in the executor's registry.
        ///
        /// ## Serialization
        /// Only one operation may be in-flight at a time per write ID.
        /// Concurrent calls to `writeChunk` will serialize automatically.
        ///
        /// - Parameters:
        ///   - path: The destination path.
        ///   - options: Streaming write options (commit strategy, durability).
        /// - Returns: A write handle ID for subsequent operations.
        package func openWriteStreaming(
            to path: File.Path,
            options: File.System.Write.Streaming.Options = .init()
        ) async throws(File.IO.Error<File.System.Write.Streaming.Error>) -> File.IO.Write.Handle.ID {
            // Capture path string for Sendable closure
            let pathString = path.string

            // Open on lane (blocking operation)
            let context: PlatformWriteContext
            do {
                context = try await pool.run {
                    () throws(File.System.Write.Streaming.Error) -> PlatformWriteContext in
                    #if os(Windows)
                        try WindowsStreaming.openForStreaming(path: pathString, options: options)
                    #else
                        try POSIXStreaming.openForStreaming(path: pathString, options: options)
                    #endif
                }
            } catch {
                throw _mapIOError(error)
            }

            // Generate ID and register
            let id = generateWriteID()
            let entry = Write.Entry(context: context, path: path, options: options)
            writes[id] = entry

            return id
        }

        /// Writes a chunk of bytes to a streaming write.
        ///
        /// Chunks are written in order. This method serializes with other operations
        /// on the same write ID.
        ///
        /// - Parameters:
        ///   - bytes: The bytes to write.
        ///   - id: The write handle ID from `openWriteStreaming`.
        package func writeChunk(
            _ bytes: [UInt8],
            to id: File.IO.Write.Handle.ID
        ) async throws(File.IO.Error<File.System.Write.Streaming.Error>) {
            guard id.scope == scope else {
                throw .executor(.scopeMismatch)
            }

            guard let entry = writes[id] else {
                throw .executor(.handleNotFound)
            }

            guard entry.state == .open else {
                throw .executor(.invalidState)
            }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                do {
                    try await _waitForWrite(id: id, entry: entry)
                } catch {
                    throw .cancelled
                }
            }

            // Re-check state after waiting
            guard entry.state == .open else {
                throw .executor(.invalidState)
            }

            guard let ctx = entry.context else {
                throw .executor(.invalidState)
            }

            entry.isOperationInFlight = true

            // Execute on lane
            do {
                try await pool.run {
                    () throws(File.System.Write.Streaming.Error) in
                    #if os(Windows)
                        try WindowsStreaming.writeChunk(bytes.span, to: ctx)
                    #else
                        try POSIXStreaming.writeChunk(bytes.span, to: ctx)
                    #endif
                }
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
            } catch {
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
                throw _mapIOError(error)
            }
        }

        /// Commits a streaming write, making it durable.
        ///
        /// This syncs the file, performs atomic rename (if configured), and
        /// syncs the directory. After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `openWriteStreaming`.
        package func commitWrite(
            _ id: File.IO.Write.Handle.ID
        ) async throws(File.IO.Error<File.System.Write.Streaming.Error>) {
            guard id.scope == scope else {
                throw .executor(.scopeMismatch)
            }

            guard let entry = writes[id] else {
                throw .executor(.handleNotFound)
            }

            guard entry.state == .open else {
                throw .executor(.invalidState)
            }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                do {
                    try await _waitForWrite(id: id, entry: entry)
                } catch {
                    throw .cancelled
                }
            }

            guard let ctx = entry.context else {
                throw .executor(.invalidState)
            }

            entry.state = .committing
            entry.isOperationInFlight = true

            do {
                try await pool.run {
                    () throws(File.System.Write.Streaming.Error) in
                    #if os(Windows)
                        try WindowsStreaming.commit(ctx)
                    #else
                        try POSIXStreaming.commit(ctx)
                    #endif
                }
                // Success - clean up
                entry.context = nil
                entry.state = .closed
                entry.isOperationInFlight = false
                writes.removeValue(forKey: id)
                entry.waiters.resumeAll()
            } catch {
                // Commit failed - state is now uncertain
                entry.state = .closed
                entry.isOperationInFlight = false
                entry.waiters.resumeAll()
                writes.removeValue(forKey: id)
                throw _mapIOError(error)
            }
        }

        /// Aborts a streaming write, cleaning up the temporary file.
        ///
        /// This is idempotent - calling it multiple times is safe.
        /// After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `openWriteStreaming`.
        package func abortWrite(_ id: File.IO.Write.Handle.ID) async {
            guard id.scope == scope else { return }
            guard let entry = writes[id] else { return }
            guard entry.state == .open || entry.state == .aborting else { return }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                await _waitForWriteNonThrowing(id: id, entry: entry)
            }

            entry.state = .aborting
            entry.isOperationInFlight = true

            // Extract context before closure
            if let ctx = entry.context {
                // Best-effort cleanup
                _ = try? await lane.run(deadline: nil) {
                    #if os(Windows)
                        WindowsStreaming.cleanup(ctx)
                    #else
                        POSIXStreaming.cleanup(ctx)
                    #endif
                }
            }

            entry.context = nil
            entry.state = .closed
            entry.isOperationInFlight = false
            writes.removeValue(forKey: id)
            entry.waiters.resumeAll()
        }

        // MARK: - Write Helpers

        private func generateWriteID() -> File.IO.Write.Handle.ID {
            let raw = nextWriteRawID
            nextWriteRawID += 1
            return File.IO.Write.Handle.ID(raw: raw, scope: scope)
        }

        private func _waitForWrite(
            id: File.IO.Write.Handle.ID,
            entry: Write.Entry
        ) async throws(CancellationError) {
            let token = entry.waiters.generateToken()

            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    _ = entry.waiters.enqueue(token: token, continuation: continuation)
                }
            } onCancel: {
                Task { await self._cancelWriteWaiter(token: token, for: id) }
            }

            if Task.isCancelled {
                throw CancellationError()
            }
        }

        private func _waitForWriteNonThrowing(id: File.IO.Write.Handle.ID, entry: Write.Entry) async {
            let token = entry.waiters.generateToken()

            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    _ = entry.waiters.enqueue(token: token, continuation: continuation)
                }
            } onCancel: {
                Task { await self._cancelWriteWaiter(token: token, for: id) }
            }
        }

        private func _cancelWriteWaiter(token: UInt64, for id: File.IO.Write.Handle.ID) {
            guard let entry = writes[id] else { return }
            if let continuation = entry.waiters.cancel(token: token) {
                continuation.resume()
            }
        }

        // MARK: - Error Mapping

        private func _mapIOError<E: Swift.Error & Sendable>(
            _ error: IO.Error<E>
        ) -> File.IO.Error<E> {
            switch error {
            case .operation(let e):
                return .operation(e)
            case .handle(let e):
                return .handle(e)
            case .executor(let e):
                return .executor(_mapExecutorError(e))
            case .lane(let f):
                return .lane(f)
            case .cancelled:
                return .cancelled
            }
        }

        private func _mapExecutorError(_ error: IO.Executor.Error) -> File.IO.Executor.Error {
            switch error {
            case .shutdownInProgress:
                return .shutdownInProgress
            case .scopeMismatch:
                return .scopeMismatch
            case .handleNotFound:
                return .handleNotFound
            case .invalidState:
                return .invalidState
            }
        }

        private func _mapTransactionError<E: Swift.Error & Sendable>(
            _ error: IO.Executor.Transaction.Error<E>
        ) -> File.IO.Executor.Transaction.Error<E> {
            switch error {
            case .lane(let f):
                return .lane(f)
            case .handle(let e):
                return .handle(e)
            case .body(let e):
                return .body(e)
            }
        }
    }
}
