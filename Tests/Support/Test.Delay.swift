//
//  Test.Delay.swift
//  swift-file-system
//
//  Foundation-free delay utilities for tests.
//  Works on Windows, Linux, and macOS without Foundation.
//

#if os(Windows)
    import WinSDK
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(Darwin)
    import Darwin
#endif

/// Test utilities namespace.
public enum Test {
    /// Delay utilities for tests that need to wait for OS-level operations.
    public enum Delay {
        /// Sleep for the specified number of milliseconds.
        ///
        /// Use sparingly - prefer retry loops with short delays over single long delays.
        public static func milliseconds(_ ms: UInt32) {
            #if os(Windows)
                Sleep(ms)
            #elseif canImport(Glibc) || canImport(Musl) || canImport(Darwin)
                usleep(ms * 1_000)
            #endif
        }
    }

    /// Retry utilities for flaky operations (e.g., Windows file handle release).
    public enum Retry {
        /// Retry an operation with delays between attempts.
        ///
        /// Useful for Windows where antivirus/indexer can briefly hold file handles.
        ///
        /// - Parameters:
        ///   - attempts: Maximum number of attempts (must be >= 1).
        ///   - delayMs: Delay in milliseconds between attempts.
        ///   - body: The operation to retry.
        /// - Returns: The result of the successful operation.
        /// - Throws: The error from the last failed attempt.
        public static func withDelay<T>(
            attempts: Int,
            delayMs: UInt32 = 50,
            _ body: () throws -> T
        ) rethrows -> T {
            precondition(attempts >= 1, "attempts must be >= 1")
            for _ in 0..<(attempts - 1) {
                do {
                    return try body()
                } catch {
                    Delay.milliseconds(delayMs)
                }
            }
            // Final attempt - let any error propagate
            return try body()
        }
    }
}
