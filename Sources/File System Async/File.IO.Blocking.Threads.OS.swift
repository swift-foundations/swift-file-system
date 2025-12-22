//
//  File.IO.Blocking.Threads.OS.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

// MARK: - Safety Invariant
//
// This is the ONLY file in File System Async allowed to contain @unchecked Sendable.
// All primitives here are low-level OS wrappers with internal synchronization.
// They are used only by the Threads lane implementation.

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

extension File.IO.Blocking.Threads {
    /// A mutex + condition variable pair for thread coordination.
    ///
    /// ## Safety Invariant
    /// - All access to protected data occurs within `withLock`.
    /// - Wait operations must be called within locked context.
    final class Lock: @unchecked Sendable {
        #if os(Windows)
            private var srwlock: SRWLOCK = SRWLOCK()
            private var condvar: CONDITION_VARIABLE = CONDITION_VARIABLE()
        #else
            private var mutex: pthread_mutex_t = pthread_mutex_t()
            private var cond: pthread_cond_t = pthread_cond_t()
        #endif

        init() {
            #if os(Windows)
                InitializeSRWLock(&srwlock)
                InitializeConditionVariable(&condvar)
            #else
                var attr = pthread_mutexattr_t()
                pthread_mutexattr_init(&attr)
                pthread_mutex_init(&mutex, &attr)
                pthread_mutexattr_destroy(&attr)
                pthread_cond_init(&cond, nil)
            #endif
        }

        deinit {
            #if !os(Windows)
                pthread_cond_destroy(&cond)
                pthread_mutex_destroy(&mutex)
            #endif
        }

        // MARK: - Lock Operations

        func withLock<T>(_ body: () throws -> T) rethrows -> T {
            #if os(Windows)
                AcquireSRWLockExclusive(&srwlock)
                defer { ReleaseSRWLockExclusive(&srwlock) }
            #else
                pthread_mutex_lock(&mutex)
                defer { pthread_mutex_unlock(&mutex) }
            #endif
            return try body()
        }

        func lock() {
            #if os(Windows)
                AcquireSRWLockExclusive(&srwlock)
            #else
                pthread_mutex_lock(&mutex)
            #endif
        }

        func unlock() {
            #if os(Windows)
                ReleaseSRWLockExclusive(&srwlock)
            #else
                pthread_mutex_unlock(&mutex)
            #endif
        }

        // MARK: - Condition Operations

        /// Wait on the condition. Must be called while holding the lock.
        func wait() {
            #if os(Windows)
                _ = SleepConditionVariableSRW(&condvar, &srwlock, INFINITE, 0)
            #else
                pthread_cond_wait(&cond, &mutex)
            #endif
        }

        /// Wait on the condition with a timeout. Must be called while holding the lock.
        ///
        /// - Parameter nanoseconds: Maximum wait time in nanoseconds.
        /// - Returns: `true` if signaled, `false` if timed out.
        func wait(timeoutNanoseconds nanoseconds: UInt64) -> Bool {
            #if os(Windows)
                let milliseconds = nanoseconds / 1_000_000
                let result = SleepConditionVariableSRW(
                    &condvar,
                    &srwlock,
                    DWORD(min(milliseconds, UInt64(DWORD.max))),
                    0
                )
                return result
            #else
                var ts = timespec()
                clock_gettime(CLOCK_REALTIME, &ts)
                let seconds = nanoseconds / 1_000_000_000
                let remainingNanos = nanoseconds % 1_000_000_000
                ts.tv_sec += Int(seconds)
                ts.tv_nsec += Int(remainingNanos)
                if ts.tv_nsec >= 1_000_000_000 {
                    ts.tv_sec += 1
                    ts.tv_nsec -= 1_000_000_000
                }
                let result = pthread_cond_timedwait(&cond, &mutex, &ts)
                return result == 0
            #endif
        }

        /// Signal one waiting thread.
        func signal() {
            #if os(Windows)
                WakeConditionVariable(&condvar)
            #else
                pthread_cond_signal(&cond)
            #endif
        }

        /// Signal all waiting threads.
        func broadcast() {
            #if os(Windows)
                WakeAllConditionVariable(&condvar)
            #else
                pthread_cond_broadcast(&cond)
            #endif
        }
    }
}

extension File.IO.Blocking.Threads {
    /// Spawns a dedicated OS thread.
    ///
    /// - Parameter body: The work to run on the new thread.
    /// - Returns: An opaque handle to the thread.
    static func spawnThread(_ body: @escaping @Sendable () -> Void) -> ThreadHandle {
        #if os(Windows)
            var threadHandle: HANDLE?
            let context = UnsafeMutablePointer<(@Sendable () -> Void)>.allocate(capacity: 1)
            context.initialize(to: body)

            threadHandle = CreateThread(
                nil,
                0,
                { context in
                    guard let ctx = context else { return 0 }
                    let body = ctx.assumingMemoryBound(to: (@Sendable () -> Void).self)
                    let work = body.move()
                    body.deallocate()
                    work()
                    return 0
                },
                context,
                0,
                nil
            )
            return ThreadHandle(handle: threadHandle!)
        #elseif canImport(Darwin)
            var thread: pthread_t?
            let contextPtr = UnsafeMutablePointer<(@Sendable () -> Void)>.allocate(capacity: 1)
            contextPtr.initialize(to: body)

            pthread_create(
                &thread,
                nil,
                { ctx in
                    let bodyPtr = ctx.assumingMemoryBound(to: (@Sendable () -> Void).self)
                    let work = bodyPtr.move()
                    bodyPtr.deallocate()
                    work()
                    return nil
                },
                contextPtr
            )

            return ThreadHandle(thread: thread!)
        #else
            // Linux: pthread_t is non-optional
            var thread: pthread_t = 0
            let contextPtr = UnsafeMutablePointer<(@Sendable () -> Void)>.allocate(capacity: 1)
            contextPtr.initialize(to: body)

            pthread_create(
                &thread,
                nil,
                { ctx in
                    guard let ctx else { return nil }
                    let bodyPtr = ctx.assumingMemoryBound(to: (@Sendable () -> Void).self)
                    let work = bodyPtr.move()
                    bodyPtr.deallocate()
                    work()
                    return nil
                },
                contextPtr
            )

            return ThreadHandle(thread: thread)
        #endif
    }
}

extension File.IO.Blocking.Threads {
    /// Opaque handle to an OS thread.
    struct ThreadHandle: @unchecked Sendable {
        #if os(Windows)
            let handle: HANDLE

            init(handle: HANDLE) {
                self.handle = handle
            }

            func join() {
                WaitForSingleObject(handle, INFINITE)
                CloseHandle(handle)
            }
        #else
            let thread: pthread_t

            init(thread: pthread_t) {
                self.thread = thread
            }

            func join() {
                pthread_join(thread, nil)
            }
        #endif
    }
}

// MARK: - CPU Count

extension File.IO.Blocking.Threads {
    /// Returns the number of active processors.
    static var processorCount: Int {
        #if canImport(Darwin)
            return Int(sysconf(_SC_NPROCESSORS_ONLN))
        #elseif canImport(Glibc)
            return Int(sysconf(Int32(_SC_NPROCESSORS_ONLN)))
        #elseif os(Windows)
            return Int(GetActiveProcessorCount(WORD(ALL_PROCESSOR_GROUPS)))
        #else
            return 4
        #endif
    }
}

// MARK: - Worker.State

extension File.IO.Blocking.Threads.Worker {
    /// Shared mutable state for all workers in the lane.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// All access to mutable fields is protected by `lock`.
    /// This is enforced through the Lock's `withLock` method.
    final class State: @unchecked Sendable {
        let lock: File.IO.Blocking.Threads.Lock
        var queue: File.IO.Blocking.Threads.Job.Queue
        var pendingQueue: File.IO.Blocking.Threads.Pending.Queue
        var isShutdown: Bool
        var inFlightCount: Int
        var nextPendingToken: UInt64

        init(queueLimit: Int) {
            self.lock = File.IO.Blocking.Threads.Lock()
            self.queue = File.IO.Blocking.Threads.Job.Queue(capacity: queueLimit)
            self.pendingQueue = File.IO.Blocking.Threads.Pending.Queue()
            self.isShutdown = false
            self.inFlightCount = 0
            self.nextPendingToken = 0
        }

        func generateToken() -> UInt64 {
            let token = nextPendingToken
            nextPendingToken &+= 1
            return token
        }
    }
}

// MARK: - Job

extension File.IO.Blocking.Threads {
    /// Namespace for job-related types.
    enum Job {}
}

extension File.IO.Blocking.Threads.Job {
    /// A type-erased job that encapsulates work and completion.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// Jobs are created and consumed under the Worker.State lock.
    /// The work closure is marked @Sendable and captures only Sendable state.
    struct Instance: @unchecked Sendable {
        private let work: @Sendable () -> Void

        /// Creates a job that executes an operation and resumes a continuation.
        init<T: Sendable>(
            operation: @Sendable @escaping () throws -> T,
            continuation: CheckedContinuation<T, any Swift.Error>
        ) {
            self.work = {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        /// An empty placeholder job.
        static let empty = Instance {}

        private init(_ work: @Sendable @escaping () -> Void) {
            self.work = work
        }

        /// Execute the job.
        func run() {
            work()
        }

        /// Fail a continuation with an error.
        static func fail<T: Sendable>(
            continuation: CheckedContinuation<T, any Swift.Error>,
            with error: any Swift.Error
        ) {
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - Pending

extension File.IO.Blocking.Threads {
    /// Namespace for pending/backpressure-related types.
    enum Pending {}
}

extension File.IO.Blocking.Threads.Pending {
    /// A pending job waiting for queue capacity (backpressure).
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// Only accessed under Worker.State lock. Contains a continuation
    /// that will be resumed exactly once (either on admission or cancellation).
    struct Job: @unchecked Sendable {
        let token: UInt64
        let job: File.IO.Blocking.Threads.Job.Instance
        let continuation: CheckedContinuation<Void, any Swift.Error>
        var isCancelled: Bool = false

        init(
            token: UInt64,
            job: File.IO.Blocking.Threads.Job.Instance,
            continuation: CheckedContinuation<Void, any Swift.Error>
        ) {
            self.token = token
            self.job = job
            self.continuation = continuation
        }
    }
}

// MARK: - Job.Queue

extension File.IO.Blocking.Threads.Job {
    /// A bounded circular buffer queue for jobs.
    ///
    /// ## Thread Safety
    /// All access must be protected by Worker.State.lock.
    struct Queue {
        private var storage: [Instance]
        private var head: Int = 0
        private var tail: Int = 0
        private var _count: Int = 0
        private let capacity: Int

        init(capacity: Int) {
            self.capacity = max(capacity, 1)
            self.storage = [Instance](repeating: Instance.empty, count: self.capacity)
        }

        var count: Int { _count }
        var isEmpty: Bool { _count == 0 }
        var isFull: Bool { _count >= capacity }

        mutating func enqueue(_ job: Instance) {
            precondition(!isFull, "Queue is full")
            storage[tail] = job
            tail = (tail + 1) % capacity
            _count += 1
        }

        mutating func dequeue() -> Instance? {
            guard _count > 0 else { return nil }
            let job = storage[head]
            storage[head] = .empty
            head = (head + 1) % capacity
            _count -= 1
            return job
        }

        mutating func drainAll() -> [Instance] {
            var result: [Instance] = []
            result.reserveCapacity(_count)
            while let job = dequeue() {
                result.append(job)
            }
            return result
        }
    }
}

// MARK: - Pending.Queue

extension File.IO.Blocking.Threads.Pending {
    /// Queue of pending jobs waiting for capacity.
    struct Queue {
        private var storage: [Job] = []

        var isEmpty: Bool { storage.isEmpty }
        var count: Int { storage.count }

        mutating func append(_ pending: Job) {
            storage.append(pending)
        }

        /// Remove and return the first non-cancelled pending job.
        mutating func popFirst() -> Job? {
            while let first = storage.first {
                storage.removeFirst()
                if !first.isCancelled {
                    return first
                }
            }
            return nil
        }

        /// Mark a pending job as cancelled by token.
        mutating func cancel(token: UInt64) -> Job? {
            for i in storage.indices {
                if storage[i].token == token && !storage[i].isCancelled {
                    storage[i].isCancelled = true
                    return storage[i]
                }
            }
            return nil
        }

        /// Drain all pending jobs (for shutdown).
        mutating func drainAll() -> [Job] {
            let result = storage
            storage = []
            return result
        }
    }
}

// MARK: - Threads.Runtime

extension File.IO.Blocking.Threads {
    /// Mutable runtime state for the Threads lane.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - `state` is thread-safe via its internal lock
    /// - `threads` is only mutated in `start()` before any concurrent access
    /// - `isStarted` and `threads` mutations are synchronized via state.lock
    final class Runtime: @unchecked Sendable {
        let state: Worker.State
        private(set) var threads: [ThreadHandle] = []
        private(set) var isStarted: Bool = false
        let options: Options

        init(options: Options) {
            self.options = options
            self.state = Worker.State(queueLimit: options.queueLimit)
        }

        func startIfNeeded() {
            state.lock.lock()
            defer { state.lock.unlock() }

            guard !isStarted else { return }
            isStarted = true

            for i in 0..<options.workers {
                let worker = Worker(id: i, state: state)
                let handle = spawnThread {
                    worker.run()
                }
                threads.append(handle)
            }
        }

        func joinAllThreads() {
            for thread in threads {
                thread.join()
            }
            threads.removeAll()
        }
    }
}

// MARK: - Atomic Counter

extension File.IO.Blocking.Threads {
    /// Thread-safe counter for generating unique IDs.
    ///
    /// Uses the Lock from this file to ensure all synchronization primitives
    /// are consolidated in Threads.OS.swift.
    final class Counter: @unchecked Sendable {
        private let lock = Lock()
        private var value: UInt64 = 0

        init() {}

        func next() -> UInt64 {
            lock.withLock {
                let result = value
                value += 1
                return result
            }
        }
    }
}
