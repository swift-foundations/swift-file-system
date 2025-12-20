//
//  File.System.Write.Atomic.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parent(File.System.Parent.Check.Error)
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
}

// MARK: - CustomStringConvertible

extension File.System.Write.Atomic.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parent(let error):
            return "Parent directory error: \(error)"
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
