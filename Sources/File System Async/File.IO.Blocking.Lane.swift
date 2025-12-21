//
//  File.IO.Blocking.Lane.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO.Blocking {
    /// A lane for executing blocking I/O operations.
    ///
    /// ## Design
    /// Lanes provide a uniform interface for running blocking syscalls without
    /// starving Swift's cooperative thread pool. Each lane implementation declares
    /// its capabilities, allowing the executor to adapt its behavior accordingly.
    ///
    /// ## Cancellation Contract
    /// - **Before acceptance**: If task is cancelled before the lane accepts the job,
    ///   `run()` throws `CancellationError` immediately without enqueuing.
    /// - **After acceptance**: If `guaranteesRunOnceEnqueued` is true, the job runs
    ///   to completion. The caller may observe `CancellationError` upon return,
    ///   but the operation's side effects occur.
    ///
    /// ## Deadline Contract
    /// - Deadlines bound acceptance time (waiting to enqueue), not execution time.
    /// - Lanes are not required to interrupt syscalls once executing.
    /// - If deadline expires before acceptance, throw lane-specific error.
    public protocol Lane: Sendable {
        /// The capabilities this lane provides.
        var capabilities: Capabilities { get }

        /// Execute a blocking operation on the lane.
        ///
        /// - Parameters:
        ///   - deadline: Optional deadline bounding acceptance time.
        ///   - operation: The blocking operation to execute.
        /// - Returns: The result of the operation.
        /// - Throws: `CancellationError` if cancelled before acceptance.
        /// - Throws: Lane-specific errors for deadline expiry or shutdown.
        func run<T: Sendable>(
            deadline: Deadline?,
            _ operation: @Sendable @escaping () throws -> T
        ) async throws -> T

        /// Shut down the lane.
        ///
        /// After shutdown:
        /// - New `run()` calls throw shutdown error.
        /// - In-flight operations complete.
        /// - Workers exit deterministically.
        func shutdown() async
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
