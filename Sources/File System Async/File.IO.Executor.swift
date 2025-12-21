//
//  File.IO.Executor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO {
    /// The executor for async file I/O operations.
    ///
    /// ## Design
    /// The executor delegates blocking syscalls to a `Lane` (default: `Threads` lane).
    /// This design provides:
    /// - Dedicated threads for blocking I/O (no starvation of cooperative pool)
    /// - Bounded queue with configurable backpressure
    /// - Deterministic shutdown semantics
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
        /// The lane for executing blocking operations.
        private let lane: any File.IO.Blocking.Lane

        /// Unique scope identifier for this executor instance.
        public nonisolated let scope: UInt64

        /// Counter for generating unique handle IDs.
        private var nextRawID: UInt64 = 0

        /// Whether this is the shared default executor (does not require shutdown).
        private let isDefaultExecutor: Bool

        /// Whether shutdown has been initiated.
        private var isShutdown: Bool = false

        /// Actor-owned handle registry.
        /// Each entry holds a File.Handle (or nil if checked out) plus waiters.
        private var handles: [File.IO.Handle.ID: Handle.Entry] = [:]

        /// Actor-owned streaming write registry.
        /// Each entry holds a platform write context plus state and waiters.
        private var writes: [File.IO.Write.Handle.ID: Write.Entry] = [:]

        /// Global counter for generating unique scope IDs.
        private static let scopeCounter = File.IO.Blocking.Threads.Counter()

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
        public static let `default` = Executor(default: File.IO.Blocking.Threads())

        // MARK: - Initializers

        /// Creates an executor with the given lane.
        ///
        /// Executors created with this initializer **must** be shut down
        /// when no longer needed using `shutdown()`.
        ///
        /// - Parameter lane: The lane for executing blocking operations.
        public init(lane: any File.IO.Blocking.Lane) {
            self.lane = lane
            self.scope = Self.scopeCounter.next()
            self.isDefaultExecutor = false
        }

        /// Creates an executor with default Threads lane options.
        ///
        /// This is a convenience initializer equivalent to:
        /// ```swift
        /// Executor(lane: File.IO.Blocking.Threads(options))
        /// ```
        ///
        /// - Parameter options: Options for the Threads lane.
        public init(_ options: File.IO.Blocking.Threads.Options = .init()) {
            self.lane = File.IO.Blocking.Threads(options)
            self.scope = Self.scopeCounter.next()
            self.isDefaultExecutor = false
        }

        /// Private initializer for the default executor.
        private init(default lane: any File.IO.Blocking.Lane) {
            self.lane = lane
            self.scope = Self.scopeCounter.next()
            self.isDefaultExecutor = true
        }

        // MARK: - Execution

        /// Execute a blocking operation on the lane.
        ///
        /// ## Cancellation Semantics
        /// - Cancellation before acceptance → `CancellationError` (job not enqueued)
        /// - Cancellation after acceptance → job still runs (if lane guarantees it),
        ///   but caller receives `CancellationError` instead of result
        ///
        /// - Parameter operation: The blocking operation to execute.
        /// - Returns: The result of the operation.
        /// - Throws: `Executor.Error.shutdownInProgress` if executor is shut down.
        /// - Throws: `CancellationError` if task is cancelled.
        /// - Throws: Lane-specific errors (queue full, deadline exceeded).
        public func run<T: Sendable>(
            _ operation: @Sendable @escaping () throws -> T
        ) async throws -> T {
            guard !isShutdown else {
                throw Executor.Error.shutdownInProgress
            }

            do {
                return try await lane.run(deadline: nil, operation)
            } catch let error as File.IO.Blocking.Threads.Error {
                // Map lane shutdown to executor shutdown error
                if error == .shutdown {
                    throw Executor.Error.shutdownInProgress
                }
                throw error
            }
        }

        // MARK: - Shutdown

        /// Shut down the executor.
        ///
        /// 1. Marks executor as shut down (rejects new `run()` calls)
        /// 2. Resumes all waiters so they can exit gracefully
        /// 3. Closes all remaining handles via heap cell pattern
        /// 4. Shuts down the lane
        ///
        /// - Note: Calling `shutdown()` on the `.default` executor is a no-op.
        ///   The default executor is process-scoped and does not require shutdown.
        public func shutdown() async {
            // Default executor is process-scoped - shutdown is a no-op
            guard !isDefaultExecutor else { return }

            guard !isShutdown else { return }  // Idempotent
            isShutdown = true

            // Resume all waiters so they can observe shutdown
            for (_, entry) in handles {
                entry.waiters.resumeAll()
                entry.isDestroyed = true
            }

            // Close all remaining handles using slot pattern
            for (id, entry) in handles {
                if let h = entry.handle.take() {
                    do {
                        try await _closeHandle(h)
                    } catch {
                        #if DEBUG
                        print("Warning: Failed to close handle \(id) during shutdown: \(error)")
                        #endif
                    }
                }
            }
            handles.removeAll()

            // Shutdown the lane
            await lane.shutdown()
        }

        // MARK: - Handle Management

        /// Generate a unique handle ID.
        private func generateHandleID() -> File.IO.Handle.ID {
            let raw = nextRawID
            nextRawID += 1
            return File.IO.Handle.ID(raw: raw, scope: scope)
        }

        // MARK: - Transaction API

        /// Execute a transaction with exclusive handle access.
        ///
        /// ## Algorithm (per plan)
        /// 1. Validate scope and existence
        /// 2. If handle available: move out (entry.handle = nil)
        /// 3. Else: enqueue waiter and suspend (cancellation-safe)
        /// 4. Execute via heap cell: allocate cell, run on lane, move handle back
        /// 5. Check-in: restore handle or close if destroyed
        /// 6. Resume next non-cancelled waiter
        ///
        /// ## Cancellation Semantics
        /// - Cancellation while waiting: waiter marked cancelled, resumes, throws CancellationError
        /// - Cancellation after checkout: lane operation completes (if guaranteed),
        ///   handle is checked in, then CancellationError is thrown
        public func transaction<T: Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws -> T
        ) async throws -> T {
            // Step 1: Validate scope
            guard id.scope == scope else {
                throw File.IO.Handle.Error.scopeMismatch
            }

            // Step 2: Checkout handle (with waiting if needed)
            guard let entry = handles[id] else {
                throw File.IO.Handle.Error.invalidID
            }

            if entry.isDestroyed {
                throw File.IO.Handle.Error.invalidID
            }

            // If handle is available, take it
            var checkedOutHandle: File.Handle
            if let h = entry.handle.take() {
                checkedOutHandle = h
            } else {
                // Step 3: Handle is checked out - wait for it
                let token = entry.waiters.generateToken()

                await withTaskCancellationHandler {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        entry.waiters.enqueue(token: token, continuation: continuation)
                    }
                } onCancel: {
                    Task { await self._cancelWaiter(token: token, for: id) }
                }

                // Check cancellation after waking
                try Task.checkCancellation()

                // Re-validate after waiting
                guard let entry = handles[id], !entry.isDestroyed else {
                    throw File.IO.Handle.Error.invalidID
                }

                guard let h = entry.handle.take() else {
                    throw File.IO.Handle.Error.invalidID
                }

                checkedOutHandle = h
            }

            // Step 4: Execute body on lane using slot pattern
            // Slot stays on actor; only the integer address is captured by @Sendable closure
            var slot = Slot.allocate()
            slot.initialize(with: checkedOutHandle)
            let address = slot.address

            let result: Result<T, any Swift.Error>
            do {
                let value = try await lane.run(deadline: nil) {
                    let raw = UnsafeMutableRawPointer(bitPattern: address)!
                    return try Slot.withHandle(at: raw) { handle in
                        try body(&handle)
                    }
                }
                result = .success(value)
            } catch {
                result = .failure(error)
            }

            // Check if task was cancelled during execution
            let wasCancelled = Task.isCancelled

            // Move handle back out of slot and deallocate
            let checkedInHandle = slot.take()
            slot.deallocateRawOnly()

            // Step 5: Check-in handle
            if let entry = handles[id] {
                if entry.isDestroyed {
                    // Entry marked for destruction - close handle via slot
                    handles.removeValue(forKey: id)
                    try? await _closeHandle(checkedInHandle)
                } else {
                    // Store handle back
                    entry.handle = consume checkedInHandle
                    // Step 6: Resume next waiter
                    entry.waiters.resumeNext()
                }
            } else {
                // Entry was removed during checkout - close handle
                try? await _closeHandle(checkedInHandle)
            }

            // Handle cancellation
            if wasCancelled {
                throw CancellationError()
            }

            return try result.get()
        }

        /// Cancel a waiter (called from cancellation handler).
        private func _cancelWaiter(token: UInt64, for id: File.IO.Handle.ID) {
            guard let entry = handles[id] else { return }
            if let continuation = entry.waiters.cancel(token: token) {
                continuation.resume()
            }
        }

        /// Close a handle using the slot pattern.
        ///
        /// This is the single point where handles are closed via lane.run.
        /// Uses the integer address to bridge ~Copyable across await.
        private func _closeHandle(_ handle: consuming File.Handle) async throws {
            var slot = Slot.allocate()
            defer { slot.deallocateRawOnly() }
            slot.initialize(with: handle)
            let address = slot.address

            try await lane.run(deadline: nil) {
                let raw = UnsafeMutableRawPointer(bitPattern: address)!
                try Slot.closeHandle(at: raw)
            }
            // Handle was consumed by closeHandle, slot memory deallocated by defer
        }

        /// Register a file handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: A unique handle ID for future operations.
        /// - Throws: `Executor.Error.shutdownInProgress` if executor is shut down.
        public func registerHandle(_ handle: consuming File.Handle) throws -> File.IO.Handle.ID {
            guard !isShutdown else {
                throw Executor.Error.shutdownInProgress
            }
            let id = generateHandleID()
            handles[id] = Handle.Entry(handle: handle)
            return id
        }

        /// Open a file and register it, returning the handle ID.
        ///
        /// This combines opening (blocking, on lane) with registration (actor-isolated)
        /// in a single operation, avoiding the need to pass ~Copyable handles across await.
        ///
        /// - Parameters:
        ///   - path: The path to the file.
        ///   - mode: The access mode.
        ///   - options: Additional options.
        /// - Returns: A handle ID for future operations.
        /// - Throws: `Executor.Error.shutdownInProgress` if executor is shut down.
        /// - Throws: File open errors.
        public func openFile(
            _ path: File.Path,
            mode: File.Handle.Mode,
            options: File.Handle.Options = [.closeOnExec]
        ) async throws -> File.IO.Handle.ID {
            guard !isShutdown else {
                throw Executor.Error.shutdownInProgress
            }

            // Open file on lane using slot pattern
            var slot = Slot.allocate()
            defer { slot.deallocateRawOnly() }
            let address = slot.address

            try await lane.run(deadline: nil) {
                let raw = UnsafeMutableRawPointer(bitPattern: address)!
                let handle = try File.Handle.open(path, mode: mode, options: options)
                Slot.initializeMemory(at: raw, with: handle)
            }

            slot.markInitialized()
            let handle = slot.take()

            let id = generateHandleID()
            handles[id] = Handle.Entry(handle: handle)
            return id
        }

        /// Execute a closure with exclusive access to a handle.
        ///
        /// This is a convenience wrapper over `transaction(_:_:)`.
        ///
        /// - Parameters:
        ///   - id: The handle ID.
        ///   - body: Closure receiving inout access to the handle.
        /// - Returns: The result of the closure.
        /// - Throws: `Handle.Error.scopeMismatch` if ID belongs to different executor.
        /// - Throws: `Handle.Error.invalidID` if handle was already destroyed.
        /// - Throws: Any error from the closure.
        public func withHandle<T: Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws -> T
        ) async throws -> T {
            try await transaction(id, body)
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `Handle.Error.scopeMismatch` if ID belongs to different executor.
        /// - Throws: Close errors from the underlying handle.
        /// - Note: Idempotent for handles that were already destroyed.
        public func destroyHandle(_ id: File.IO.Handle.ID) async throws {
            guard id.scope == scope else {
                throw File.IO.Handle.Error.scopeMismatch
            }

            guard let entry = handles[id] else {
                // Already destroyed - idempotent
                return
            }

            if entry.isDestroyed {
                // Already marked for destruction
                return
            }

            // Mark as destroyed
            entry.isDestroyed = true

            // If handle is checked out, it will be closed on check-in
            // If handle is available, close it now using slot pattern
            if let h = entry.handle.take() {
                handles.removeValue(forKey: id)
                try await _closeHandle(h)
            }
        }

        /// Check if a handle ID is currently valid.
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle exists and is not destroyed.
        public func isHandleValid(_ id: File.IO.Handle.ID) -> Bool {
            guard let entry = handles[id] else { return false }
            return !entry.isDestroyed
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
        public func openWriteStreaming(
            to path: File.Path,
            options: File.System.Write.Streaming.Options = .init()
        ) async throws -> File.IO.Write.Handle.ID {
            guard !isShutdown else {
                throw File.IO.Blocking.Threads.Error.shutdown
            }

            // Capture path string for Sendable closure
            let pathString = path.string

            // Open on lane (blocking operation)
            let context: PlatformWriteContext = try await lane.run(deadline: nil) {
                #if os(Windows)
                try WindowsStreaming.openForStreaming(path: pathString, options: options)
                #else
                try POSIXStreaming.openForStreaming(path: pathString, options: options)
                #endif
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
        public func writeChunk(
            _ bytes: [UInt8],
            to id: File.IO.Write.Handle.ID
        ) async throws {
            guard id.scope == scope else {
                throw File.IO.Executor.Error.scopeMismatch
            }

            guard let entry = writes[id] else {
                throw File.IO.Executor.Error.handleNotFound
            }

            guard entry.state == .open else {
                throw File.IO.Executor.Error.invalidState
            }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                try await _waitForWrite(id: id, entry: entry)
            }

            // Re-check state after waiting
            guard entry.state == .open else {
                throw File.IO.Executor.Error.invalidState
            }

            guard let ctx = entry.context else {
                throw File.IO.Executor.Error.invalidState
            }

            entry.isOperationInFlight = true

            do {
                // Extract context before closure (ctx is Sendable)
                try await lane.run(deadline: nil) {
                    try bytes.withUnsafeBufferPointer { buffer in
                        let span = Span(_unsafeElements: buffer)
                        #if os(Windows)
                        try WindowsStreaming.writeChunk(span, to: ctx)
                        #else
                        try POSIXStreaming.writeChunk(span, to: ctx)
                        #endif
                    }
                }
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
            } catch {
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
                throw error
            }
        }

        /// Commits a streaming write, making it durable.
        ///
        /// This syncs the file, performs atomic rename (if configured), and
        /// syncs the directory. After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `openWriteStreaming`.
        /// - Throws: `File.System.Write.Streaming.Error` on failure.
        public func commitWrite(_ id: File.IO.Write.Handle.ID) async throws {
            guard id.scope == scope else {
                throw File.IO.Executor.Error.scopeMismatch
            }

            guard let entry = writes[id] else {
                throw File.IO.Executor.Error.handleNotFound
            }

            guard entry.state == .open else {
                throw File.IO.Executor.Error.invalidState
            }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                try await _waitForWrite(id: id, entry: entry)
            }

            guard let ctx = entry.context else {
                throw File.IO.Executor.Error.invalidState
            }

            entry.state = .committing
            entry.isOperationInFlight = true

            do {
                // Extract context before closure (ctx is Sendable)
                try await lane.run(deadline: nil) {
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
                throw error
            }
        }

        /// Aborts a streaming write, cleaning up the temporary file.
        ///
        /// This is idempotent - calling it multiple times is safe.
        /// After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `openWriteStreaming`.
        public func abortWrite(_ id: File.IO.Write.Handle.ID) async {
            guard id.scope == scope else { return }
            guard let entry = writes[id] else { return }
            guard entry.state == .open || entry.state == .aborting else { return }

            // Wait if operation in flight
            if entry.isOperationInFlight {
                await _waitForWriteNonThrowing(id: id, entry: entry)
            }

            entry.state = .aborting
            entry.isOperationInFlight = true

            // Extract context before closure (ctx is Sendable)
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
            let raw = nextRawID
            nextRawID += 1
            return File.IO.Write.Handle.ID(raw: raw, scope: scope)
        }

        private func _waitForWrite(id: File.IO.Write.Handle.ID, entry: Write.Entry) async throws {
            let token = entry.waiters.generateToken()

            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    entry.waiters.enqueue(token: token, continuation: continuation)
                }
            } onCancel: {
                Task { await self._cancelWriteWaiter(token: token, for: id) }
            }

            try Task.checkCancellation()
        }

        private func _waitForWriteNonThrowing(id: File.IO.Write.Handle.ID, entry: Write.Entry) async {
            let token = entry.waiters.generateToken()

            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    entry.waiters.enqueue(token: token, continuation: continuation)
                }
            } onCancel: {
                Task { await self._cancelWriteWaiter(token: token, for: id) }
            }
        }

        /// Cancel a write waiter (called from cancellation handler).
        private func _cancelWriteWaiter(token: UInt64, for id: File.IO.Write.Handle.ID) {
            guard let entry = writes[id] else { return }
            if let continuation = entry.waiters.cancel(token: token) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Legacy Configuration Support

extension File.IO.Executor {
    /// Creates an executor with legacy configuration.
    ///
    /// This initializer maps the legacy `Configuration` to appropriate lane options.
    /// For new code, prefer using `init(lane:)` or `init(_:)` directly.
    ///
    /// - Parameter configuration: Legacy configuration.
    @available(*, deprecated, message: "Use init(lane:) or init(_:) instead")
    public init(_ configuration: File.IO.Configuration) {
        let options = File.IO.Blocking.Threads.Options(
            workers: configuration.workers,
            queueLimit: configuration.queueLimit,
            backpressure: .suspend
        )
        self.init(options)
    }
}
