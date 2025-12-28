//
//  File.System.Write.Streaming.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// Parent directory verification or creation failed.
        case parent(File.System.Parent.Check.Error)
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

        /// The streaming write is not in a valid state for this operation.
        ///
        /// This occurs when trying to write to a closed or committed stream.
        case invalidState

        /// Random token generation failed.
        ///
        /// This is an extremely rare error indicating the kernel CSPRNG failed.
        case randomGenerationFailed(errno: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension File.System.Write.Streaming.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .parent(let error):
            return "Parent directory error: \(error)"
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
        case .invalidState:
            return "Streaming write is not in a valid state for this operation"
        case .randomGenerationFailed(let errno, let message):
            return "Random token generation failed: \(message) (errno=\(errno))"
        }
    }
}
