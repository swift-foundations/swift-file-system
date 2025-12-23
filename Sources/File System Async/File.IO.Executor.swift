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
        private let lane: File.IO.Blocking.Lane

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
        public static let `default` = Executor(default: .threads())

        // MARK: - Initializers

        /// Creates an executor with the given lane.
        ///
        /// Executors created with this initializer **must** be shut down
        /// when no longer needed using `shutdown()`.
        ///
        /// - Parameter lane: The lane for executing blocking operations.
        public init(lane: File.IO.Blocking.Lane) {
            self.lane = lane
            self.scope = Self.scopeCounter.next()
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
        public init(_ options: File.IO.Blocking.Threads.Options = .init()) {
            self.lane = .threads(options)
            self.scope = Self.scopeCounter.next()
            self.isDefaultExecutor = false
        }

        /// Private initializer for the default executor.
        private init(default lane: File.IO.Blocking.Lane) {
            self.lane = lane
            self.scope = Self.scopeCounter.next()
            self.isDefaultExecutor = true
        }

        // MARK: - Execution

        /// Execute a blocking operation on the lane with typed throws.
        ///
        /// This method preserves the operation's specific error type while also
        /// capturing I/O infrastructure errors in `File.IO.Error<E>`.
        ///
        /// ## Example
        /// ```swift
        /// let data = try await executor.run {
        ///     try File.System.Read.Full.read(from: path)
        /// }
        /// // Error type: File.IO.Error<File.System.Read.Full.Error>
        /// ```
        ///
        /// ## Cancellation Semantics
        /// - Cancellation before acceptance → `.cancelled`
        /// - Cancellation after acceptance → operation completes, then `.cancelled`
        ///
        /// - Parameter operation: The blocking operation to execute.
        /// - Returns: The result of the operation.
        /// - Throws: `File.IO.Error<E>` with the specific operation error or infrastructure error.
        public func run<
            T: Sendable,
            E: Swift.Error & Sendable
        >(
            _ operation: @Sendable @escaping () throws(E) -> T
        ) async throws(File.IO.Error<E>) -> T {
            guard !isShutdown else {
                throw .executor(.shutdownInProgress)
            }

            // Lane.run throws(Lane.Failure) and returns Result<T, E>
            let result: Result<T, E>
            do {
                result = try await lane.run(deadline: nil, operation)
            } catch {
                // error is statically Lane.Failure due to typed throws
                switch error {
                case .shutdown:
                    throw .executor(.shutdownInProgress)
                case .queueFull:
                    throw .lane(.queueFull)
                case .deadlineExceeded:
                    throw .lane(.deadlineExceeded)
                case .cancelled:
                    throw .cancelled
                }
            }
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw .operation(error)
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
                entry.state = .destroyed
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

        /// Execute a transaction with exclusive handle access and typed errors.
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
        package func transaction<T: Sendable, E: Swift.Error & Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws(E) -> T
        ) async throws(Transaction.Error<E>) -> T {
            // Step 1: Validate scope
            guard id.scope == scope else {
                throw .handle(.scopeMismatch)
            }

            // Step 2: Checkout handle (with waiting if needed)
            guard let entry = handles[id] else {
                throw .handle(.invalidID)
            }

            if entry.state == .destroyed {
                throw .handle(.invalidID)
            }

            // If handle is available, take it
            var checkedOutHandle: File.Handle
            if entry.state == .present, let h = entry.handle.take() {
                entry.state = .checkedOut
                checkedOutHandle = h
            } else {
                // Step 3: Handle is checked out - wait for it
                let token = entry.waiters.generateToken()

                await withTaskCancellationHandler {
                    await withCheckedContinuation {
                        (continuation: CheckedContinuation<Void, Never>) in
                        entry.waiters.enqueue(token: token, continuation: continuation)
                    }
                } onCancel: {
                    Task { await self._cancelWaiter(token: token, for: id) }
                }

                // Check cancellation after waking
                do {
                    try Task.checkCancellation()
                } catch {
                    throw .lane(.cancelled)
                }

                // Re-validate after waiting
                guard let entry = handles[id], entry.state != .destroyed else {
                    throw .handle(.invalidID)
                }

                guard entry.state == .present, let h = entry.handle.take() else {
                    throw .handle(.invalidID)
                }

                entry.state = .checkedOut
                checkedOutHandle = h
            }

            // Step 4: Execute body on lane using slot pattern
            // Slot stays on actor; only the integer address is captured by @Sendable closure
            var slot = Slot.allocate()
            slot.initialize(with: checkedOutHandle)
            let address = slot.address

            // Lane.run throws(Lane.Failure) and returns Result<T, E>
            // Use the Result-returning overload with typed throws on body
            let operationResult: Result<T, E>
            do {
                operationResult = try await lane.run(deadline: nil) { () throws(E) -> T in
                    let raw = UnsafeMutableRawPointer(bitPattern: address)!
                    // Execute body with typed throws
                    // Explicit type annotation on inner closure forces E unification
                    return try Slot.withHandle(at: raw) { (handle: inout File.Handle) throws(E) -> T in
                        try body(&handle)
                    }
                }
            } catch{
                // error is statically Lane.Failure
                await _checkInHandle(slot.take(), for: id, entry: entry)
                slot.deallocateRawOnly()
                throw .lane(error)
            }

            // Check if task was cancelled during execution
            let wasCancelled = Task.isCancelled

            // Move handle back out of slot and deallocate
            let checkedInHandle = slot.take()
            slot.deallocateRawOnly()

            // Step 5: Check-in handle
            await _checkInHandle(checkedInHandle, for: id, entry: entry)

            // Handle cancellation
            if wasCancelled {
                throw .lane(.cancelled)
            }

            // Return result or throw body error
            switch operationResult {
            case .success(let value):
                return value
            case .failure(let bodyError):
                throw .body(bodyError)
            }
        }

        /// Check-in a handle after transaction.
        ///
        /// ## Invariants
        /// - Actor state is updated BEFORE any await (no intermediate states visible)
        /// - Non-copyable handle moved via Slot pattern across await boundary
        /// - Deterministic close (no fire-and-forget Task)
        private func _checkInHandle(
            _ handle: consuming File.Handle,
            for id: File.IO.Handle.ID,
            entry: Handle.Entry
        ) async {
            if entry.state == .destroyed {
                // 1. Update actor state FIRST (before any await)
                //    Entry removed from dictionary so no interleaving can access it
                handles.removeValue(forKey: id)

                // 2. Move handle into slot for transport across await
                var slot = Slot.allocate()
                slot.initialize(with: handle)
                let address = slot.address
                defer { slot.deallocateRawOnly() }

                // 3. Deterministically await close on lane
                //    Errors swallowed since we're cleaning up destroyed entry
                _ = try? await lane.run(deadline: nil) { () -> Void in
                    let raw = UnsafeMutableRawPointer(bitPattern: address)!
                    try? Slot.closeHandle(at: raw)
                }
            } else {
                // Sync path - store handle back and resume waiter
                entry.handle = consume handle
                entry.state = .present
                entry.waiters.resumeNext()
            }
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
        private func _closeHandle(_ handle: consuming File.Handle) async throws(File.IO.Error<File.Handle.Error>) {
            var slot = Slot.allocate()
            defer { slot.deallocateRawOnly() }
            slot.initialize(with: handle)
            let address = slot.address

            let result: Result<Void, File.Handle.Error>
            do {
                result = try await lane.run(deadline: nil) { () throws(File.Handle.Error) -> Void in
                    let raw = UnsafeMutableRawPointer(bitPattern: address)!
                    try Slot.closeHandle(at: raw)
                }
            } catch {
                throw .lane(error)
            }
            
            switch result {
            case .success:
                break
            case .failure(let error):
                throw .operation(error)
            }
            // Handle was consumed by closeHandle, slot memory deallocated by defer
        }

        /// Register a file handle and return its ID.
        ///
        /// - Parameter handle: The handle to register (ownership transferred).
        /// - Returns: A unique handle ID for future operations.
        /// - Throws: `Executor.Error.shutdownInProgress` if executor is shut down.
        package func registerHandle(_ handle: consuming File.Handle) throws(File.IO.Executor.Error) -> File.IO.Handle.ID {
            guard !isShutdown else {
                throw .shutdownInProgress
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
        /// - Throws: `File.IO.Error<File.Handle.Error>` on failure.
        package func openFile(
            _ path: File.Path,
            mode: File.Handle.Mode,
            options: File.Handle.Options = [.closeOnExec]
        ) async throws(File.IO.Error<File.Handle.Error>) -> File.IO.Handle.ID {
            guard !isShutdown else {
                throw .executor(.shutdownInProgress)
            }

            // Open file on lane using slot pattern
            var slot = Slot.allocate()
            defer { slot.deallocateRawOnly() }
            let address = slot.address

            // Execute lane.run - only throws Lane.Failure
            let result: Result<Void, File.Handle.Error>
            do {
                // Use typed-throws lane.run - Lane handles the quarantined cast
                result = try await lane.run(deadline: nil) { () throws(File.Handle.Error) -> Void in
                    let raw = UnsafeMutableRawPointer(bitPattern: address)!
                    let handle = try File.Handle.open(path, mode: mode, options: options)
                    Slot.initializeMemory(at: raw, with: handle)
                }
            } catch {
                switch error {
                case .shutdown:
                    throw .executor(.shutdownInProgress)
                case .queueFull:
                    throw .lane(.queueFull)
                case .deadlineExceeded:
                    throw .lane(.deadlineExceeded)
                case .cancelled:
                    throw .cancelled
                }
            }

            // Handle operation result (outside do-catch for proper type inference)
            switch result {
            case .success:
                break
            case .failure(let error):
                throw .operation(error)
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
        /// - Throws: `File.IO.Error<E>` on failure.
        package func withHandle<T: Sendable, E: Swift.Error & Sendable>(
            _ id: File.IO.Handle.ID,
            _ body: @Sendable @escaping (inout File.Handle) throws(E) -> T
        ) async throws(File.IO.Error<E>) -> T {
            do {
                return try await transaction(id, body)
            } catch {
                switch error {
                case .lane(let error):
                    switch error {
                    case .shutdown:
                        throw .executor(.shutdownInProgress)
                    case .queueFull:
                        throw .lane(.queueFull)
                    case .deadlineExceeded:
                        throw .lane(.deadlineExceeded)
                    case .cancelled:
                        throw .cancelled
                    }
                case .handle(let handleError):
                    throw .handle(handleError)
                case .body(let bodyError):
                    throw .operation(bodyError)
                }
            }
        }

        /// Close and remove a handle.
        ///
        /// - Parameter id: The handle ID.
        /// - Throws: `File.IO.Error<File.Handle.Error>` on failure.
        /// - Note: Idempotent for handles that were already destroyed.
        package func destroyHandle(_ id: File.IO.Handle.ID) async throws(File.IO.Error<File.Handle.Error>) {
            guard id.scope == scope else {
                throw .handle(.scopeMismatch)
            }

            guard let entry = handles[id] else {
                // Already destroyed - idempotent
                return
            }

            if entry.state == .destroyed {
                // Already marked for destruction
                return
            }

            // If handle is checked out, mark for destruction on check-in
            if entry.state == .checkedOut {
                entry.state = .destroyed
                // Drain waiters so they wake and see destroyed state
                entry.waiters.resumeAll()
                return
            }

            // Handle is present - close it now using slot pattern
            entry.state = .destroyed

            // Drain all waiters BEFORE removing entry
            // They will wake, re-check, find entry.state == .destroyed, and throw
            entry.waiters.resumeAll()

            if let h = entry.handle.take() {
                handles.removeValue(forKey: id)
                try await _closeHandle(h)
            }
        }

        /// Check if a handle ID is currently valid.
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle exists and is not destroyed.
        package func isHandleValid(_ id: File.IO.Handle.ID) -> Bool {
            guard let entry = handles[id] else { return false }
            return entry.state != .destroyed
        }

        /// Check if a handle ID refers to an open handle.
        ///
        /// This is the source of truth for handle liveness. Returns true if:
        /// - The ID belongs to this executor (scope match)
        /// - An entry exists in the registry
        /// - The entry is present or checked out (not destroyed)
        ///
        /// - Parameter id: The handle ID to check.
        /// - Returns: `true` if the handle is logically open.
        package func isHandleOpen(_ id: File.IO.Handle.ID) -> Bool {
            guard id.scope == scope else { return false }
            guard let entry = handles[id] else { return false }
            return entry.isOpen
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
            guard !isShutdown else {
                throw .executor(.shutdownInProgress)
            }

            // Capture path string for Sendable closure
            let pathString = path.string

            // Open on lane (blocking operation)
            let result: Result<PlatformWriteContext, File.System.Write.Streaming.Error>
            do {
                result = try await lane.run(deadline: nil) { () throws(File.System.Write.Streaming.Error) -> PlatformWriteContext in
                    #if os(Windows)
                        try WindowsStreaming.openForStreaming(path: pathString, options: options)
                    #else
                        try POSIXStreaming.openForStreaming(path: pathString, options: options)
                    #endif
                }
            } catch {
                switch error {
                case .shutdown:
                    throw .executor(.shutdownInProgress)
                case .queueFull:
                    throw .lane(.queueFull)
                case .deadlineExceeded:
                    throw .lane(.deadlineExceeded)
                case .cancelled:
                    throw .cancelled
                }
            }

            // Handle operation result
            let context: PlatformWriteContext
            switch result {
            case .success(let ctx):
                context = ctx
            case .failure(let error):
                throw .operation(error)
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

            // Execute lane.run with typed throws
            let result: Result<Void, File.System.Write.Streaming.Error>
            do {
                // Extract context before closure (ctx is Sendable)
                result = try await lane.run(deadline: nil) { () throws(File.System.Write.Streaming.Error) -> Void in
                    #if os(Windows)
                        try WindowsStreaming.writeChunk(bytes.span, to: ctx)
                    #else
                        try POSIXStreaming.writeChunk(bytes.span, to: ctx)
                    #endif
                }
            } catch {
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
                switch error {
                case .shutdown:
                    throw .executor(.shutdownInProgress)
                case .queueFull:
                    throw .lane(.queueFull)
                case .deadlineExceeded:
                    throw .lane(.deadlineExceeded)
                case .cancelled:
                    throw .cancelled
                }
            }

            // Handle operation result
            switch result {
            case .success:
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
            case .failure(let error):
                entry.isOperationInFlight = false
                entry.waiters.resumeNext()
                throw .operation(error)
            }
        }

        /// Commits a streaming write, making it durable.
        ///
        /// This syncs the file, performs atomic rename (if configured), and
        /// syncs the directory. After this call, the write ID is no longer valid.
        ///
        /// - Parameter id: The write handle ID from `openWriteStreaming`.
        /// - Throws: `File.System.Write.Streaming.Error` on failure.
        package func commitWrite(_ id: File.IO.Write.Handle.ID) async throws(File.IO.Error<File.System.Write.Streaming.Error>) {
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

            // Execute lane.run - only throws Lane.Failure
            let result: Result<Void, File.System.Write.Streaming.Error>
            do {
                // Extract context before closure (ctx is Sendable)
                result = try await lane.run(deadline: nil) { () throws(File.System.Write.Streaming.Error) -> Void in
                    #if os(Windows)
                        try WindowsStreaming.commit(ctx)
                    #else
                        try POSIXStreaming.commit(ctx)
                    #endif
                }
            } catch {
                // Commit failed - state is now uncertain
                entry.state = .closed
                entry.isOperationInFlight = false
                entry.waiters.resumeAll()
                writes.removeValue(forKey: id)
                switch error {
                case .shutdown:
                    throw .executor(.shutdownInProgress)
                case .queueFull:
                    throw .lane(.queueFull)
                case .deadlineExceeded:
                    throw .lane(.deadlineExceeded)
                case .cancelled:
                    throw .cancelled
                }
            }

            // Handle operation result
            switch result {
            case .success:
                // Success - clean up
                entry.context = nil
                entry.state = .closed
                entry.isOperationInFlight = false
                writes.removeValue(forKey: id)
                entry.waiters.resumeAll()
            case .failure(let error):
                // Commit failed - state is now uncertain
                entry.state = .closed
                entry.isOperationInFlight = false
                entry.waiters.resumeAll()
                writes.removeValue(forKey: id)
                throw .operation(error)
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

        private func _waitForWrite(id: File.IO.Write.Handle.ID, entry: Write.Entry) async throws(CancellationError) {
            let token = entry.waiters.generateToken()

            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    entry.waiters.enqueue(token: token, continuation: continuation)
                }
            } onCancel: {
                Task { await self._cancelWriteWaiter(token: token, for: id) }
            }

            // Use Task.isCancelled and explicit throw for typed throws compatibility
            // (Task.checkCancellation() uses untyped throws in stdlib)
            if Task.isCancelled {
                throw CancellationError()
            }
        }

        private func _waitForWriteNonThrowing(id: File.IO.Write.Handle.ID, entry: Write.Entry) async
        {
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

// MARK: - Transaction.Error

extension File.IO.Executor {
    /// Namespace for transaction-related types.
    public enum Transaction {}
}

extension File.IO.Executor.Transaction {
    /// Typed error for transaction operations.
    /// Generic over the body error E - no existentials, full structure preserved.
    public enum Error<E: Swift.Error & Sendable>: Swift.Error, Sendable {
        case lane(File.IO.Blocking.Lane.Failure)
        case handle(File.IO.Handle.Error)
        case body(E)
    }
}
