//
//  File.System.Error.Code.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import WinSDK
#endif

extension File.System.Error {
    /// Platform-specific system error code.
    ///
    /// Separates POSIX errno values from Windows error codes for proper diagnostics.
    /// Use `.posix(_)` for Unix-like systems (Darwin, Linux, etc.) and `.windows(_)`
    /// for Windows API errors.
    ///
    /// ## Example
    /// ```swift
    /// case .posix(let errno):
    ///     print("POSIX error: \(errno)")
    /// case .windows(let code):
    ///     print("Windows error: \(code)")
    /// ```
    public enum Code: Equatable, Sendable {
        /// POSIX errno value (Unix-like systems).
        case posix(Int32)

        /// Windows API error code (from GetLastError()).
        case windows(UInt32)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Error.Code: CustomStringConvertible {
    public var description: String {
        switch self {
        case .posix(let errno):
            #if !os(Windows)
            if let msg = strerror(errno) {
                return "errno \(errno): \(String(cString: msg))"
            }
            #endif
            return "errno \(errno)"

        case .windows(let code):
            return "Windows error \(code)"
        }
    }
}

// MARK: - Convenience Initializers

extension File.System.Error.Code {
    /// Creates an error code from the current platform's last error.
    ///
    /// On POSIX systems, reads `errno`. On Windows, calls `GetLastError()`.
    @inline(__always)
    public static func current() -> Self {
        #if os(Windows)
        return .windows(GetLastError())
        #else
        return .posix(errno)
        #endif
    }

    /// The raw numeric value for display purposes.
    public var rawValue: Int64 {
        switch self {
        case .posix(let errno): return Int64(errno)
        case .windows(let code): return Int64(code)
        }
    }
}

// MARK: - Error Message Helper

extension File.System.Error.Code {
    /// Returns a human-readable message for this error code.
    public var message: String {
        switch self {
        case .posix(let errno):
            #if !os(Windows)
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            #endif
            return "error \(errno)"

        case .windows(let code):
            return "Windows error \(code)"
        }
    }
}

// MARK: - Backward Compatibility

extension File.System {
    /// Backward compatibility alias for `Error.Code`.
    @available(*, deprecated, renamed: "Error.Code")
    public typealias ErrorCode = Error.Code
}
