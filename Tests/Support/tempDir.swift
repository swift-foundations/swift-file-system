public import File_System_Primitives
public import Formatting

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Returns the system temp directory path using POSIX getenv.
/// Falls back to "/tmp" if TMPDIR is not set.
public func tempDir() throws -> File.Path {
    let path: String
    if let ptr = getenv("TMPDIR") {
        path = String(cString: ptr)
    } else {
        path = "/tmp"
    }
    return try File.Path(path)
}

// MARK: - Timing (Foundation-free)

/// High-resolution monotonic clock for benchmarking.
/// Uses POSIX clock_gettime - no Foundation required.
public struct MonotonicClock {
    private var ts: timespec

    /// Captures the current monotonic time.
    public init() {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        self.ts = ts
    }

    /// Returns seconds elapsed since this clock was created.
    public func elapsed() -> Double {
        var now = timespec()
        clock_gettime(CLOCK_MONOTONIC, &now)
        let seconds = Double(now.tv_sec - ts.tv_sec)
        let nanos = Double(now.tv_nsec - ts.tv_nsec)
        return seconds + nanos / 1_000_000_000
    }

    /// Returns milliseconds elapsed since this clock was created.
    public func elapsedMs() -> Double {
        elapsed() * 1000
    }
}
