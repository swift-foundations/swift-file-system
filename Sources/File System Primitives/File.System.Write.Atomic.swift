// File.System.Write.Atomic.swift
// Atomic file writing with crash-safety guarantees
//
// This module provides atomic file writes using the standard pattern:
//   1. Write to a temporary file in the same directory
//   2. Sync the file to disk (fsync)
//   3. Atomically rename temp → destination (rename is atomic on POSIX/NTFS)
//   4. Sync the directory to ensure the rename is persisted
//
// This guarantees that on any crash or power failure, you either have:
//   - The complete new file, or
//   - The complete old file (or no file if it didn't exist)
// You never get a partial/corrupted file.
//
// ## Security Considerations
//
// ### Symlink/Reparse-Point Handling
// This library does NOT provide hardened path resolution against symlink attacks.
// The O_NOFOLLOW flag (when used) only protects the final path component.
//
// **Threat model:**
// - Safe for: Writing to directories YOU control (application data, caches)
// - NOT safe for: Writing to attacker-controlled paths (e.g., /tmp with user input)
//
// Intermediate path components can still be symlinks, enabling TOCTOU attacks
// where an attacker replaces a directory with a symlink between path validation
// and file creation.
//
// For security-critical use cases in adversarial environments, consider:
// 1. Using openat() with O_NOFOLLOW at each path component
// 2. Validating the entire path is within expected bounds before writing
// 3. Using OS-provided secure temp directory APIs
// 4. Avoiding user-controlled path components entirely

import Binary

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    public import WinSDK
#endif

extension File.System.Write {
    /// Atomic file writing with crash-safety guarantees.
    public enum Atomic {

        // MARK: - Strategy

        /// Controls behavior when the destination file already exists.
        public enum Strategy: Sendable {
            /// Replace the existing file atomically (default).
            case replaceExisting

            /// Fail if the destination already exists.
            case noClobber
        }

        // MARK: - Durability

        /// Controls the durability guarantees for file synchronization.
        ///
        /// Higher durability modes provide stronger crash-safety but slower performance.
        public enum Durability: Sendable {
            /// Full synchronization with F_FULLFSYNC on macOS (default).
            ///
            /// Guarantees data is written to physical storage and survives power loss.
            /// Slowest but safest option.
            case full

            /// Data-only synchronization without metadata sync where available.
            ///
            /// Uses fdatasync() on Linux or F_BARRIERFSYNC on macOS if available.
            /// Faster than `.full` but still durable for most use cases.
            /// Falls back to fsync if platform-specific optimizations unavailable.
            case dataOnly

            /// No synchronization - data may be buffered in OS caches.
            ///
            /// Fastest option but provides no crash-safety guarantees.
            /// Suitable for caches, temporary files, or build artifacts.
            case none
        }

        // MARK: - Options

        /// Options controlling atomic write behavior.
        public struct Options: Sendable {
            public var strategy: Strategy
            public var durability: Durability
            public var preservePermissions: Bool
            public var preserveOwnership: Bool
            public var strictOwnership: Bool
            public var preserveTimestamps: Bool
            public var preserveExtendedAttributes: Bool
            public var preserveACLs: Bool

            public init(
                strategy: Strategy = .replaceExisting,
                durability: Durability = .full,
                preservePermissions: Bool = true,
                preserveOwnership: Bool = false,
                strictOwnership: Bool = false,
                preserveTimestamps: Bool = false,
                preserveExtendedAttributes: Bool = false,
                preserveACLs: Bool = false
            ) {
                self.strategy = strategy
                self.durability = durability
                self.preservePermissions = preservePermissions
                self.preserveOwnership = preserveOwnership
                self.strictOwnership = strictOwnership
                self.preserveTimestamps = preserveTimestamps
                self.preserveExtendedAttributes = preserveExtendedAttributes
                self.preserveACLs = preserveACLs
            }
        }

        // MARK: - Commit

        /// Namespace for commit-related types.
        public enum Commit {
        }
    }
}

// MARK: - Commit.Phase

extension File.System.Write.Atomic.Commit {
    /// Tracks progress through the atomic write operation.
    ///
    /// Use `published` to determine if the file exists at its destination after failure.
    /// Use `durabilityAttempted` for postmortem diagnostics.
    ///
    /// ## Usage
    /// After catching an error, check the phase to understand the file state:
    /// ```swift
    /// do {
    ///     try atomicWrite(data, to: path)
    /// } catch {
    ///     if phase.published {
    ///         // File exists at destination, but durability may be compromised
    ///     } else {
    ///         // File was NOT written to destination
    ///     }
    /// }
    /// ```
    public enum Phase: UInt8, Sendable, Equatable {
        /// Operation not yet started.
        case pending = 0

        /// Writing data to temp file.
        case writing = 1

        /// File data synced to disk.
        case syncedFile = 2

        /// Temp file closed.
        case closed = 3

        /// File atomically renamed to destination (published).
        case renamedPublished = 4

        /// Directory sync was started but not confirmed complete.
        case directorySyncAttempted = 5

        /// Directory synced, fully durable.
        case syncedDirectory = 6
    }
}

// MARK: - Commit.Phase Properties

extension File.System.Write.Atomic.Commit.Phase {
    /// Returns true if file has been atomically published to destination.
    ///
    /// When this is true, the file exists with complete contents at the destination path.
    /// However, durability may not be guaranteed if `durabilityAttempted` is false.
    public var published: Bool { self.rawValue >= Self.renamedPublished.rawValue }

    /// Returns true if directory sync was attempted (for postmortem diagnostics).
    ///
    /// Distinguishes "sync started but failed/cancelled" from "sync never attempted".
    public var durabilityAttempted: Bool { self.rawValue >= Self.directorySyncAttempted.rawValue }
}

extension File.System.Write.Atomic {

    // MARK: - Error

    public enum Error: Swift.Error, Equatable, Sendable {
        case parentNotFound(path: File.Path)
        case parentNotDirectory(path: File.Path)
        case parentAccessDenied(path: File.Path)
        case destinationStatFailed(path: File.Path, code: File.System.Error.Code, message: String)
        case tempFileCreationFailed(directory: File.Path, code: File.System.Error.Code, message: String)
        case writeFailed(bytesWritten: Int, bytesExpected: Int, code: File.System.Error.Code, message: String)
        case syncFailed(code: File.System.Error.Code, message: String)
        case closeFailed(code: File.System.Error.Code, message: String)
        case metadataPreservationFailed(operation: String, code: File.System.Error.Code, message: String)
        case renameFailed(from: File.Path, to: File.Path, code: File.System.Error.Code, message: String)
        case destinationExists(path: File.Path)
        case directorySyncFailed(path: File.Path, code: File.System.Error.Code, message: String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation. The caller should NOT attempt
        /// to "finish durability" - this is not reliably possible.
        case directorySyncFailedAfterCommit(path: File.Path, code: File.System.Error.Code, message: String)

        /// CSPRNG failed - cannot generate secure temp file names.
        ///
        /// This indicates a fundamental system failure (e.g., getrandom syscall failure).
        /// The operation cannot proceed safely without secure random bytes.
        case randomGenerationFailed(code: File.System.Error.Code, operation: String, message: String)

        /// Platform layout incompatibility at runtime.
        ///
        /// This occurs when platform-specific struct layouts don't match expectations.
        /// Typically indicates a need for fallback to alternative APIs.
        case platformIncompatible(operation: String, message: String)
    }

    // MARK: - Core API

    /// Atomically writes bytes to a file path.
    ///
    /// This is the core primitive - all other write operations compose on top of this.
    ///
    /// ## Guarantees
    /// - Either the file exists with complete contents, or the original state is preserved
    /// - On success, data is synced to physical storage (survives power loss)
    /// - Safe to call concurrently for different paths
    ///
    /// ## Requirements
    /// - Parent directory must exist and be writable
    ///
    /// - Parameters:
    ///   - bytes: The data to write (borrowed, zero-copy)
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write(
        _ bytes: borrowing Span<UInt8>,
        to path: File.Path,
        options: borrowing Options = Options()
    ) throws(Error) {
        #if os(Windows)
            try WindowsAtomic.writeSpan(bytes, to: path.string, options: options)
        #else
            try POSIXAtomic.writeSpan(bytes, to: path.string, options: options)
        #endif
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic {
    /// Atomically writes a Binary.Serializable value to a file path.
    ///
    /// Uses `withSerializedBytes` for zero-copy access when the type supports it.
    ///
    /// - Parameters:
    ///   - value: The serializable value to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write<S: Binary.Serializable>(
        _ value: S,
        to path: File.Path,
        options: Options = Options()
    ) throws(Error) {
        try S.withSerializedBytes(value) { (span: borrowing Span<UInt8>) throws(Error) in
            try write(span, to: path, options: options)
        }
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Atomic {
    /// Returns a human-readable error message for a system error code.
    @usableFromInline
    static func errorMessage(for code: File.System.Error.Code) -> String {
        code.message
    }

    /// Legacy helper for migration - converts errno to ErrorCode.
    @usableFromInline
    static func errorMessage(for errno: Int32) -> String {
        #if os(Windows)
            return "error \(errno)"
        #else
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            return "error \(errno)"
        #endif
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Atomic.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parentNotFound(let path):
            return "Parent directory not found: \(path)"
        case .parentNotDirectory(let path):
            return "Parent path is not a directory: \(path)"
        case .parentAccessDenied(let path):
            return "Access denied to parent directory: \(path)"
        case .destinationStatFailed(let path, let code, let message):
            return "Failed to stat destination '\(path)': \(message) (\(code))"
        case .tempFileCreationFailed(let directory, let code, let message):
            return "Failed to create temp file in '\(directory)': \(message) (\(code))"
        case .writeFailed(let written, let expected, let code, let message):
            return "Write failed after \(written)/\(expected) bytes: \(message) (\(code))"
        case .syncFailed(let code, let message):
            return "Sync failed: \(message) (\(code))"
        case .closeFailed(let code, let message):
            return "Close failed: \(message) (\(code))"
        case .metadataPreservationFailed(let op, let code, let message):
            return "Metadata preservation failed (\(op)): \(message) (\(code))"
        case .renameFailed(let from, let to, let code, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (\(code))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let code, let message):
            return "Directory sync failed '\(path)': \(message) (\(code))"
        case .directorySyncFailedAfterCommit(let path, let code, let message):
            return "Directory sync failed after commit '\(path)': \(message) (\(code))"
        case .randomGenerationFailed(let code, let operation, let message):
            return "Random generation failed (\(operation)): \(message) (\(code))"
        case .platformIncompatible(let operation, let message):
            return "Platform incompatible (\(operation)): \(message)"
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic.Strategy: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .replaceExisting: return 0
        case .noClobber: return 1
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .replaceExisting
        case 1: self = .noClobber
        default: return nil
        }
    }
}

extension File.System.Write.Atomic.Strategy: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

extension File.System.Write.Atomic.Durability: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .full: return 0
        case .dataOnly: return 1
        case .none: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .full
        case 1: self = .dataOnly
        case 2: self = .none
        default: return nil
        }
    }
}

extension File.System.Write.Atomic.Durability: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}

// MARK: - Comparable

extension File.System.Write.Atomic.Commit.Phase: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Backward Compatibility

extension File.System.Write.Atomic {
    @available(*, deprecated, renamed: "Commit.Phase")
    public typealias CommitPhase = Commit.Phase
}
