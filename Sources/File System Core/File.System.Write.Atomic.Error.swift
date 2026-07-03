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

extension File.System.Write.Atomic {
    /// Errors that can occur during atomic write operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parentVerificationFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Stat on destination file failed.
        case destinationStatFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Temp file creation failed.
        case tempFileCreationFailed(directory: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Write operation failed.
        case writeFailed(bytesWritten: Int, bytesExpected: Int, code: Error_Primitives.Error.Code, message: Swift.String)

        /// File sync (fsync/flush) failed.
        case syncFailed(code: Error_Primitives.Error.Code, message: Swift.String)

        /// File close failed.
        case closeFailed(code: Error_Primitives.Error.Code, message: Swift.String)

        /// Metadata preservation failed.
        case metadataPreservationFailed(operation: Swift.String, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Timestamp preservation failed.
        case timestampPreservationFailed(Kernel.File.Times.Error)

        /// Atomic rename failed.
        case renameFailed(from: File.Path, to: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Destination already exists (noClobber mode).
        case destinationExists(path: File.Path)

        /// Directory sync failed (before commit completed).
        case directorySyncFailed(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// Directory sync failed after successful rename.
        ///
        /// File exists with complete content, but durability is compromised.
        /// This is an I/O error, not cancellation. The caller should NOT attempt
        /// to "finish durability" - this is not reliably possible.
        case directorySyncFailedAfterCommit(path: File.Path, code: Error_Primitives.Error.Code, message: Swift.String)

        /// CSPRNG failed - cannot generate secure temp file names.
        ///
        /// This indicates a fundamental system failure (e.g., getrandom syscall failure).
        /// The operation cannot proceed safely without secure random bytes.
        case randomGenerationFailed(code: Error_Primitives.Error.Code, operation: Swift.String, message: Swift.String)

        /// Platform layout incompatibility at runtime.
        ///
        /// This occurs when platform-specific struct layouts don't match expectations.
        /// Typically indicates a need for fallback to alternative APIs.
        case platformIncompatible(operation: Swift.String, message: Swift.String)

        /// The input path could not be validated as a `File.Path`.
        ///
        /// Wraps the typed `Paths.Path.Error` surfaced by `File.Path.init(_:)`
        /// so the specific failure mode (empty, interior NUL, control chars)
        /// is preserved without re-description.
        case invalidPath(Paths.Path.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Write.Atomic.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .destinationStatFailed(_, let code, _),
            .tempFileCreationFailed(_, let code, _):
            return code.isNotFound

        default:
            return false
        }
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .destinationStatFailed(_, let code, _),
            .tempFileCreationFailed(_, let code, _),
            .writeFailed(_, _, let code, _),
            .syncFailed(let code, _),
            .closeFailed(let code, _),
            .metadataPreservationFailed(_, let code, _),
            .renameFailed(_, _, let code, _),
            .directorySyncFailed(_, let code, _),
            .directorySyncFailedAfterCommit(_, let code, _):
            return code.isPermissionDenied

        case .randomGenerationFailed(let code, _, _):
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
        case .tempFileCreationFailed(_, let code, _),
            .writeFailed(_, _, let code, _),
            .syncFailed(let code, _),
            .renameFailed(_, _, let code, _),
            .directorySyncFailed(_, let code, _),
            .directorySyncFailedAfterCommit(_, let code, _):
            return code.isReadOnly

        default:
            return false
        }
    }

    /// Returns `true` if there is no space left on device.
    public var isNoSpace: Bool {
        switch self {
        case .tempFileCreationFailed(_, let code, _),
            .writeFailed(_, _, let code, _),
            .syncFailed(let code, _):
            return code.isNoSpace

        default:
            return false
        }
    }

    /// Returns `true` if durability was compromised after successful rename.
    public var isDurabilityCompromised: Bool {
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    /// Returns `true` if the platform is incompatible.
    public var isPlatformIncompatible: Bool {
        if case .platformIncompatible = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Atomic.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .parentVerificationFailed(let path, let code, let message):
            return "Parent directory error '\(path)': \(message) (\(code))"

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

        case .timestampPreservationFailed(let error):
            return "Timestamp preservation failed (futimens): \(error)"

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

        case .invalidPath(let error):
            return "Invalid path: \(error)"
        }
    }
}
