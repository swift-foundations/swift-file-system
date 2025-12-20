// File.System.Write.Streaming.swift
// Streaming/chunked file writing with optional atomic guarantees
//
// This module provides memory-efficient file writes by processing data in chunks.
// When atomic mode is enabled (default), it uses the same temp-file pattern as
// File.System.Write.Atomic to ensure crash-safety.

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
    /// Streaming/chunked file writing with optional atomic guarantees.
    ///
    /// Memory-efficient for large files - only holds one chunk at a time.
    ///
    /// ## Usage
    /// ```swift
    /// // Atomic streaming write (crash-safe, default)
    /// try File.System.Write.Streaming.write(chunks, to: path)
    ///
    /// // Direct streaming write (faster, no crash-safety)
    /// try File.System.Write.Streaming.write(chunks, to: path, options: .init(commit: .direct()))
    /// ```
    ///
    /// ## Performance Note
    /// For optimal performance, provide chunks of 64KB–1MB. Smaller chunks work
    /// correctly but with higher overhead due to syscall frequency.
    public enum Streaming {

        // MARK: - Commit Policy

        /// Controls how chunks are committed to disk.
        public enum CommitPolicy: Sendable {
            /// Atomic write via temp file + rename (crash-safe).
            ///
            /// - Write chunks to temp file in same directory
            /// - Sync temp file according to durability
            /// - Atomically rename to destination
            /// - Sync directory to persist rename
            ///
            /// Note: Unlike `File.System.Write.Atomic`, streaming does not support
            /// metadata preservation (timestamps, xattrs, ACLs, ownership).
            case atomic(AtomicOptions = .init())

            /// Direct write to destination (faster, no crash-safety).
            ///
            /// On crash or cancellation, file may be partially written.
            case direct(DirectOptions = .init())
        }

        // MARK: - Atomic Options

        /// Options for atomic streaming writes.
        ///
        /// Note: Unlike `File.System.Write.Atomic.Options`, streaming writes do not support
        /// metadata preservation. This is a simpler options type focused on
        /// durability and existence semantics.
        public struct AtomicOptions: Sendable {
            /// Controls behavior when destination exists.
            public var strategy: AtomicStrategy

            /// Controls durability guarantees.
            public var durability: Durability

            public init(
                strategy: AtomicStrategy = .replaceExisting,
                durability: Durability = .full
            ) {
                self.strategy = strategy
                self.durability = durability
            }
        }

        /// Strategy for atomic streaming writes.
        public enum AtomicStrategy: Sendable {
            /// Replace existing file (default).
            case replaceExisting

            /// Fail if destination already exists.
            ///
            /// Uses platform-specific atomic mechanisms:
            /// - macOS/iOS: `renamex_np` with `RENAME_EXCL`
            /// - Linux: `renameat2` with `RENAME_NOREPLACE`, fallback to `link+unlink`
            /// - Windows: `MoveFileExW` without `MOVEFILE_REPLACE_EXISTING`
            case noClobber
        }

        // MARK: - Durability

        /// Controls durability guarantees for streaming writes.
        public enum Durability: Sendable {
            /// Full durability - both data and metadata synced.
            /// Uses `F_FULLFSYNC` on Darwin, `fsync` elsewhere.
            case full

            /// Data-only sync - metadata may not be persisted.
            /// Uses `F_BARRIERFSYNC` on Darwin, `fdatasync` on Linux.
            case dataOnly

            /// No sync - rely on OS buffers.
            /// Faster but data may be lost on power failure.
            case none
        }

        // MARK: - Direct Options

        /// Options for non-atomic (direct) writes.
        public struct DirectOptions: Sendable {
            /// Controls behavior when destination exists.
            public var strategy: DirectStrategy

            /// Controls durability guarantees.
            public var durability: Durability

            public init(
                strategy: DirectStrategy = .truncate,
                durability: Durability = .full
            ) {
                self.strategy = strategy
                self.durability = durability
            }
        }

        /// Strategy for direct (non-atomic) writes.
        public enum DirectStrategy: Sendable {
            /// Fail if destination exists.
            case create

            /// Truncate existing file or create new.
            case truncate
        }

        // MARK: - Options

        /// Options controlling streaming write behavior.
        public struct Options: Sendable {
            /// How to commit chunks to disk.
            public var commit: CommitPolicy

            public init(commit: CommitPolicy = .atomic(.init())) {
                self.commit = commit
            }
        }

        // MARK: - Error

        public enum Error: Swift.Error, Equatable, Sendable {
            case parentNotFound(path: File.Path)
            case parentNotDirectory(path: File.Path)
            case parentAccessDenied(path: File.Path)
            case fileCreationFailed(path: File.Path, errno: Int32, message: String)
            /// Write operation failed.
            case writeFailed(path: File.Path, bytesWritten: Int, errno: Int32, message: String)
            case syncFailed(errno: Int32, message: String)
            case closeFailed(errno: Int32, message: String)
            case renameFailed(from: File.Path, to: File.Path, errno: Int32, message: String)
            case destinationExists(path: File.Path)
            case directorySyncFailed(path: File.Path, errno: Int32, message: String)

            /// Write completed but durability guarantee not met due to cancellation.
            ///
            /// File data was flushed (fsync succeeded), but directory entry may not be persisted.
            /// The destination path exists and contains complete content.
            ///
            /// **Callers should NOT attempt to "finish durability"** - this is not reliably possible.
            case durabilityNotGuaranteed(path: File.Path, reason: String)

            /// Directory sync failed after successful rename.
            ///
            /// File exists with complete content, but durability is compromised.
            /// This is an I/O error, not cancellation.
            case directorySyncFailedAfterCommit(path: File.Path, errno: Int32, message: String)
        }

        // MARK: - Core API

        /// Writes a sequence of byte chunks to a file path.
        ///
        /// Memory-efficient for large files - processes one chunk at a time.
        /// Internally converts each chunk to Span for zero-copy writes.
        ///
        /// ## Atomic Mode (default)
        /// - Writes to a temporary file in the same directory
        /// - Syncs temp file according to durability setting
        /// - Atomically renames on completion
        /// - Syncs directory to persist the rename
        /// - Either complete new file or original state preserved on crash
        ///
        /// ## Direct Mode
        /// - Writes directly to destination
        /// - Faster but partial writes possible on crash
        ///
        /// - Parameters:
        ///   - chunks: Sequence of owned byte arrays to write
        ///   - path: Destination file path
        ///   - options: Write options
        /// - Throws: `File.System.Write.Streaming.Error` on failure
        public static func write<Chunks: Sequence>(
            _ chunks: Chunks,
            to path: File.Path,
            options: Options = Options()
        ) throws(Error) where Chunks.Element == [UInt8] {
            #if os(Windows)
                try WindowsStreaming.write(chunks, to: path.string, options: options)
            #else
                try POSIXStreaming.write(chunks, to: path.string, options: options)
            #endif
        }
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Streaming {
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

extension File.System.Write.Streaming.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parentNotFound(let path):
            return "Parent directory not found: \(path)"
        case .parentNotDirectory(let path):
            return "Parent path is not a directory: \(path)"
        case .parentAccessDenied(let path):
            return "Access denied to parent directory: \(path)"
        case .fileCreationFailed(let path, let errno, let message):
            return "Failed to create file '\(path)': \(message) (errno=\(errno))"
        case .writeFailed(let path, let written, let errno, let message):
            return "Write failed to '\(path)' after \(written) bytes: \(message) (errno=\(errno))"
        case .syncFailed(let errno, let message):
            return "Sync failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .renameFailed(let from, let to, let errno, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (errno=\(errno))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let errno, let message):
            return "Directory sync failed '\(path)': \(message) (errno=\(errno))"
        case .durabilityNotGuaranteed(let path, let reason):
            return "Write to '\(path)' completed but durability not guaranteed: \(reason)"
        case .directorySyncFailedAfterCommit(let path, let errno, let message):
            return "Directory sync failed after commit '\(path)': \(message) (errno=\(errno))"
        }
    }
}
