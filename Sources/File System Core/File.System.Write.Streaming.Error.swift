// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

extension File.System.Write.Streaming {
    /// Errors that can occur during streaming write operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parentVerificationFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// File creation failed.
        case fileCreationFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Write operation failed.
        case writeFailed(bytesWritten: Int, code: Error_Primitives.Error.Code, message: Swift.String)

        /// File sync (fsync/flush) failed.
        case syncFailed(code: Error_Primitives.Error.Code, message: Swift.String)

        /// File close failed.
        case closeFailed(code: Error_Primitives.Error.Code, message: Swift.String)

        /// Atomic rename failed.
        case renameFailed(from: File.Path, to: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Destination already exists (noClobber mode).
        case destinationExists(path: File.Path)

        /// Directory sync failed (before commit completed).
        case directorySyncFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Write completed but durability guarantee not met due to cancellation.
        ///
        /// File data was flushed (fsync succeeded), but directory entry may not be persisted.
        /// The destination path exists and contains complete content.
        ///
        /// **Callers should NOT attempt to "finish durability"** - this is not reliably possible.
        case durabilityNotGuaranteed(path: File.Path, reason: Swift.String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation.
        case directorySyncFailedAfterCommit(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// The streaming write is not in a valid state for this operation.
        ///
        /// This occurs when trying to write to a closed or committed stream.
        case invalidState

        /// Random token generation failed.
        ///
        /// This is an extremely rare error indicating the kernel CSPRNG failed.
        case randomGenerationFailed(code: Error_Primitives.Error.Code, message: Swift.String)

        /// The user-provided fill closure threw an error.
        ///
        /// Used by the reusable-buffer streaming API when the fill closure fails.
        /// The underlying error's description is preserved in the message.
        case userError(message: Swift.String)

        /// The fill closure returned more bytes than the buffer capacity.
        ///
        /// This indicates a programming error in the fill closure.
        case invalidFillResult(produced: Int, capacity: Int)

        /// The input path could not be validated as a `File.Path`.
        ///
        /// Wraps the typed `Paths.Path.Error` surfaced by `File.Path.init(_:)`
        /// so the specific failure mode (empty, interior NUL, control chars)
        /// is preserved without re-description.
        case invalidPath(Paths.Path.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Write.Streaming.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .fileCreationFailed(_, let code, _):
            return code.isNotFound
        default:
            return false
        }
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .fileCreationFailed(_, let code, _):
            return code.isPermissionDenied
        default:
            return false
        }
    }

    /// Returns `true` if the destination already exists (noClobber mode).
    public var isDestinationExists: Bool {
        if case .destinationExists = self { return true }
        return false
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        switch self {
        case .fileCreationFailed(_, let code, _),
            .writeFailed(_, let code, _):
            return code.isReadOnly
        default:
            return false
        }
    }

    /// Returns `true` if there is no space left on device.
    public var isNoSpace: Bool {
        switch self {
        case .writeFailed(_, let code, _),
            .syncFailed(let code, _):
            return code.isNoSpace
        default:
            return false
        }
    }

    /// Returns `true` if this is a user error from the fill closure.
    public var isUserError: Bool {
        if case .userError = self { return true }
        return false
    }

    /// Returns `true` if durability was not guaranteed.
    public var isDurabilityNotGuaranteed: Bool {
        if case .durabilityNotGuaranteed = self { return true }
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    /// Returns `true` if the streaming write is in an invalid state.
    public var isInvalidState: Bool {
        if case .invalidState = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Streaming.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .parentVerificationFailed(let path, let code, let message):
            return "Parent directory error '\(path)': \(message) (\(code))"
        case .fileCreationFailed(let path, let code, let message):
            return "Failed to create file '\(path)': \(message) (\(code))"
        case .writeFailed(let written, let code, let message):
            return "Write failed after \(written) bytes: \(message) (\(code))"
        case .syncFailed(let code, let message):
            return "Sync failed: \(message) (\(code))"
        case .closeFailed(let code, let message):
            return "Close failed: \(message) (\(code))"
        case .renameFailed(let from, let to, let code, let message):
            return "Rename failed '\(from)' → '\(to)': \(message) (\(code))"
        case .destinationExists(let path):
            return "Destination already exists (noClobber): \(path)"
        case .directorySyncFailed(let path, let code, let message):
            return "Directory sync failed '\(path)': \(message) (\(code))"
        case .durabilityNotGuaranteed(let path, let reason):
            return "Write to '\(path)' completed but durability not guaranteed: \(reason)"
        case .directorySyncFailedAfterCommit(let path, let code, let message):
            return "Directory sync failed after commit '\(path)': \(message) (\(code))"
        case .invalidState:
            return "Streaming write is not in a valid state for this operation"
        case .randomGenerationFailed(let code, let message):
            return "Random token generation failed: \(message) (\(code))"
        case .userError(let message):
            return "User-provided closure failed: \(message)"
        case .invalidFillResult(let produced, let capacity):
            return "Fill closure returned \(produced) bytes but buffer capacity is \(capacity)"
        case .invalidPath(let error):
            return "Invalid path: \(error)"
        }
    }
}
