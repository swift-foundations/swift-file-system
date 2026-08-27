public import Kernel

extension File.System.Write.Atomic {

    public enum Error: Swift.Error, Equatable, Sendable {

        case parentVerificationFailed(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case destinationStatFailed(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case tempFileCreationFailed(
            directory: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case writeFailed(
            bytesWritten: Int,
            bytesExpected: Int,
            code: Error.Error.Code,
            message: Swift.String
        )

        case syncFailed(code: Error.Error.Code, message: Swift.String)

        case closeFailed(code: Error.Error.Code, message: Swift.String)

        case metadataPreservationFailed(
            operation: Swift.String,
            code: Error.Error.Code,
            message: Swift.String
        )

        case timestampPreservationFailed(Kernel.File.Times.Error)

        case renameFailed(
            from: File.Path,
            to: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case destinationExists(path: File.Path)

        case directorySyncFailed(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case directorySyncFailedAfterCommit(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case randomGenerationFailed(
            code: Error.Error.Code,
            operation: Swift.String,
            message: Swift.String
        )

        case platformIncompatible(operation: Swift.String, message: Swift.String)

        case invalidPath(Paths.Path.Error)
    }
}

extension File.System.Write.Atomic.Error {

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

    public var isDestinationExists: Bool {
        if case .destinationExists = self { return true }
        return false
    }

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

    public var isDurabilityCompromised: Bool {
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    public var isPlatformIncompatible: Bool {
        if case .platformIncompatible = self { return true }
        return false
    }
}

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
