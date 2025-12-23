//
//  File.IO.Blocking.Lane.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Blocking {
    /// Protocol witness struct for blocking I/O lanes.
    ///
    /// ## Design
    /// Lanes provide a uniform interface for running blocking syscalls without
    /// starving Swift's cooperative thread pool. This is a protocol witness struct
    /// (not a protocol) to avoid existential types for Swift Embedded compatibility.
    ///
    /// ## Error Handling Design
    /// - Lane throws `Lane.Failure` for infrastructure failures (shutdown, timeout, etc.)
    /// - Operation errors flow through `Result<T, E>` - never thrown
    /// - This enables typed error propagation without existentials
    ///
    /// ## Cancellation Contract
    /// - **Before acceptance**: If task is cancelled before the lane accepts the job,
    ///   `run()` throws `.cancelled` immediately without enqueuing.
    /// - **After acceptance**: If `guaranteesRunOnceEnqueued` is true, the job runs
    ///   to completion. The caller may observe `.cancelled` upon return,
    ///   but the operation's side effects occur.
    ///
    /// ## Deadline Contract
    /// - Deadlines bound acceptance time (waiting to enqueue), not execution time.
    /// - Lanes are not required to interrupt syscalls once executing.
    /// - If deadline expires before acceptance, throw `.deadlineExceeded`.
    public struct Lane: Sendable {
        /// The capabilities this lane provides.
        public let capabilities: Capabilities

        /// The run implementation.
        /// - Operation closure returns boxed value (never throws)
        /// - Lane throws only Lane.Failure for infrastructure failures
        private let _run:
            @Sendable (
                Deadline?,
                @Sendable @escaping () -> UnsafeMutableRawPointer  // Returns boxed value
            ) async throws(Lane.Failure) -> UnsafeMutableRawPointer

        private let _shutdown: @Sendable () async -> Void

        public init(
            capabilities: Capabilities,
            run:
                @escaping @Sendable (
                    Deadline?,
                    @Sendable @escaping () -> UnsafeMutableRawPointer
                ) async throws(Lane.Failure) -> UnsafeMutableRawPointer,
            shutdown: @escaping @Sendable () async -> Void
        ) {
            self.capabilities = capabilities
            self._run = run
            self._shutdown = shutdown
        }

        // MARK: - Core Primitive (Result-returning)

        /// Execute a Result-returning operation.
        ///
        /// This is the core primitive. The operation produces a `Result<T, E>` directly,
        /// preserving the typed error without any casting or existentials.
        ///
        /// Internal to force callers through the typed-throws `run` wrapper.
        /// Lane only throws `Lane.Failure` for infrastructure failures.
        internal func runResult<T: Sendable, E: Swift.Error & Sendable>(
            deadline: Deadline?,
            _ operation: @Sendable @escaping () -> Result<T, E>
        ) async throws(Lane.Failure) -> Result<T, E> {
            let ptr = try await _run(deadline) {
                let result = operation()
                return Self.box(result)
            }
            return Self.unbox(ptr)
        }

        // MARK: - Convenience (Typed-Throws)

        /// Execute a typed-throwing operation, returning Result.
        ///
        /// This convenience wrapper converts `throws(E) -> T` to `() -> Result<T, E>`.
        ///
        /// ## Quarantined Cast (Swift Embedded Safe)
        /// Swift currently infers `error` as `any Error` even when `operation` throws(E).
        /// We use a single, localized `as?` cast to recover E without introducing
        /// existentials into storage or API boundaries. This is the ONLY cast in the
        /// module and is acceptable for Embedded compatibility.
        public func run<T: Sendable, E: Swift.Error & Sendable>(
            deadline: Deadline?,
            _ operation: @Sendable @escaping () throws(E) -> T
        ) async throws(Lane.Failure) -> Result<T, E> {
            try await runResult(deadline: deadline) {
                do {
                    return .success(try operation())
                } catch {
                    // Quarantined cast to recover E from `any Error`.
                    // This is the only cast in the module - do not add others.
                    guard let e = error as? E else {
                        // Unreachable if typed-throws is respected by the compiler.
                        // Trap to surface invariant violations during development.
                        fatalError(
                            "Lane.run: typed-throws invariant violated. Expected \(E.self), got \(type(of: error))"
                        )
                    }
                    return .failure(e)
                }
            }
        }

        // MARK: - Convenience (Non-throwing)

        /// Execute a non-throwing operation, returning value directly.
        public func run<T: Sendable>(
            deadline: Deadline?,
            _ operation: @Sendable @escaping () -> T
        ) async throws(Lane.Failure) -> T {
            let ptr = try await _run(deadline) {
                let result = operation()
                return Self.boxValue(result)
            }
            return Self.unboxValue(ptr)
        }

        public func shutdown() async {
            await _shutdown()
        }

        // MARK: - Boxing Helpers

        /// ## Boxing Ownership Rules
        ///
        /// **Invariant:** Exactly one party allocates, exactly one party frees.
        ///
        /// - **Allocation:** The operation closure allocates via `box()` inside the lane worker
        /// - **Deallocation:** The caller deallocates via `unbox()` after receiving pointer
        ///
        /// **Cancellation/Shutdown Safety:**
        /// - If a job is enqueued but never executed (shutdown), the job is dropped
        ///   but no pointer was allocated yet (allocation happens inside job execution)
        /// - If a job is executed, the pointer is always returned to the continuation
        /// - If continuation is resumed with failure, no pointer was allocated
        ///
        /// **Never allocate before enqueue.** Allocation happens inside the job body.

        private static func box<T, E: Swift.Error>(
            _ result: Result<T, E>
        ) -> UnsafeMutableRawPointer {
            let ptr = UnsafeMutablePointer<Result<T, E>>.allocate(capacity: 1)
            ptr.initialize(to: result)
            return UnsafeMutableRawPointer(ptr)
        }

        private static func unbox<T, E: Swift.Error>(_ ptr: UnsafeMutableRawPointer) -> Result<T, E> {
            let typed = ptr.assumingMemoryBound(to: Result<T, E>.self)
            let result = typed.move()
            typed.deallocate()
            return result
        }

        private static func boxValue<T>(_ value: T) -> UnsafeMutableRawPointer {
            let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
            ptr.initialize(to: value)
            return UnsafeMutableRawPointer(ptr)
        }

        private static func unboxValue<T>(_ ptr: UnsafeMutableRawPointer) -> T {
            let typed = ptr.assumingMemoryBound(to: T.self)
            let result = typed.move()
            typed.deallocate()
            return result
        }
    }
}

// MARK: - Lane.Failure

extension File.IO.Blocking.Lane {
    /// Infrastructure failures from the Lane itself.
    /// Operation errors are returned in the boxed Result, not thrown.
    public enum Failure: Swift.Error, Sendable, Equatable {
        case shutdown
        case queueFull
        case deadlineExceeded
        case cancelled
    }
}

// MARK: - Capabilities

extension File.IO.Blocking {
    /// Capabilities declared by a lane.
    ///
    /// Capabilities are truth declarations - lanes must not claim capabilities
    /// they cannot reliably provide. Core code adapts behavior based on these flags.
    public struct Capabilities: Sendable, Equatable {
        /// Whether the lane executes on dedicated OS threads.
        ///
        /// When true:
        /// - Blocking syscalls do not interfere with Swift's cooperative pool.
        /// - The executor can safely schedule long-blocking operations.
        ///
        /// When false:
        /// - The lane may use Swift's cooperative pool or other shared resources.
        /// - Sustained blocking may affect unrelated async work.
        public var executesOnDedicatedThreads: Bool

        /// Whether accepted jobs are guaranteed to run.
        ///
        /// When true:
        /// - Once a job is accepted (run() doesn't throw before enqueue),
        ///   it will execute to completion regardless of caller cancellation.
        /// - Enables safe mutation semantics: the operation runs, caller may
        ///   just not observe the result.
        ///
        /// When false:
        /// - Accepted jobs may be dropped on shutdown or cancellation.
        /// - Callers cannot rely on "run once accepted" semantics.
        public var guaranteesRunOnceEnqueued: Bool

        /// Creates capabilities with explicit values.
        public init(
            executesOnDedicatedThreads: Bool,
            guaranteesRunOnceEnqueued: Bool
        ) {
            self.executesOnDedicatedThreads = executesOnDedicatedThreads
            self.guaranteesRunOnceEnqueued = guaranteesRunOnceEnqueued
        }
    }
}

// MARK: - Deadline

extension File.IO.Blocking {
    /// A deadline for lane acceptance.
    ///
    /// Deadlines bound the time a caller waits for queue capacity or acceptance.
    /// They do not interrupt syscalls once executing.
    public struct Deadline: Sendable, Equatable {
        /// The deadline instant as a monotonic clock value.
        ///
        /// Uses `clock_gettime(CLOCK_MONOTONIC)` on POSIX or equivalent on Windows.
        public var instant: UInt64

        /// Creates a deadline at the given instant.
        public init(instant: UInt64) {
            self.instant = instant
        }
    }
}

// MARK: - Deadline Helpers

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

extension File.IO.Blocking.Deadline {
    /// The current monotonic time.
    public static var now: Self {
        #if canImport(Darwin)
            var ts = timespec()
            clock_gettime(CLOCK_MONOTONIC, &ts)
            let nanos = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
            return Self(instant: nanos)
        #elseif canImport(Glibc)
            var ts = timespec()
            clock_gettime(CLOCK_MONOTONIC, &ts)
            let nanos = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
            return Self(instant: nanos)
        #elseif os(Windows)
            var counter: LARGE_INTEGER = LARGE_INTEGER()
            var frequency: LARGE_INTEGER = LARGE_INTEGER()
            QueryPerformanceCounter(&counter)
            QueryPerformanceFrequency(&frequency)
            let nanos = UInt64(counter.QuadPart) * 1_000_000_000 / UInt64(frequency.QuadPart)
            return Self(instant: nanos)
        #else
            // Fallback: no monotonic clock available
            return Self(instant: 0)
        #endif
    }

    /// Creates a deadline relative to now.
    ///
    /// - Parameter nanoseconds: Duration from now in nanoseconds.
    /// - Returns: A deadline at `now + nanoseconds`.
    public static func after(nanoseconds: UInt64) -> Self {
        let current = now
        return Self(instant: current.instant &+ nanoseconds)
    }

    /// Creates a deadline relative to now.
    ///
    /// - Parameter milliseconds: Duration from now in milliseconds.
    /// - Returns: A deadline at `now + milliseconds`.
    public static func after(milliseconds: UInt64) -> Self {
        after(nanoseconds: milliseconds * 1_000_000)
    }

    /// Whether this deadline has passed.
    public var hasExpired: Bool {
        Self.now.instant >= instant
    }

    /// Nanoseconds remaining until deadline, or 0 if expired.
    public var remainingNanoseconds: UInt64 {
        let current = Self.now.instant
        if current >= instant {
            return 0
        }
        return instant - current
    }
}

// MARK: - Factory Methods

extension File.IO.Blocking.Lane {
    /// Creates a lane backed by dedicated OS threads.
    public static func threads(_ options: File.IO.Blocking.Threads.Options = .init()) -> Self {
        let impl = File.IO.Blocking.Threads(options)
        return Self(
            capabilities: impl.capabilities,
            run: {
                (
                    deadline: File.IO.Blocking.Deadline?,
                    operation: @Sendable @escaping () -> UnsafeMutableRawPointer
                ) async throws(File.IO.Blocking.Lane.Failure) -> UnsafeMutableRawPointer in
                try await impl.runBoxed(deadline: deadline, operation)
            },
            shutdown: { await impl.shutdown() }
        )
    }
}
