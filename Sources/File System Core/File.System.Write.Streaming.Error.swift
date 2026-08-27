public import Kernel

extension File.System.Write.Streaming {

    public enum Error: Swift.Error, Equatable, Sendable {

        case parentVerificationFailed(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case fileCreationFailed(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case writeFailed(
            bytesWritten: Int,
            code: Error.Error.Code,
            message: Swift.String
        )

        case syncFailed(code: Error.Error.Code, message: Swift.String)

        case closeFailed(code: Error.Error.Code, message: Swift.String)

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

        case durabilityNotGuaranteed(path: File.Path, reason: Swift.String)

        case directorySyncFailedAfterCommit(
            path: File.Path,
            code: Error.Error.Code,
            message: Swift.String
        )

        case invalidState

        case randomGenerationFailed(code: Error.Error.Code, message: Swift.String)

        case userError(message: Swift.String)

        case invalidFillResult(produced: Int, capacity: Int)

        case invalidPath(Paths.Path.Error)
    }
}

extension File.System.Write.Streaming.Error {

    public var isNotFound: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .fileCreationFailed(_, let code, _):
            return code.isNotFound

        default:
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .parentVerificationFailed(_, let code, _),
            .fileCreationFailed(_, let code, _):
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
        case .fileCreationFailed(_, let code, _),
            .writeFailed(_, let code, _):
            return code.isReadOnly

        default:
            return false
        }
    }

    public var isNoSpace: Bool {
        switch self {
        case .writeFailed(_, let code, _),
            .syncFailed(let code, _):
            return code.isNoSpace

        default:
            return false
        }
    }

    public var isUserError: Bool {
        if case .userError = self { return true }
        return false
    }

    public var isDurabilityNotGuaranteed: Bool {
        if case .durabilityNotGuaranteed = self { return true }
        if case .directorySyncFailedAfterCommit = self { return true }
        return false
    }

    public var isInvalidState: Bool {
        if case .invalidState = self { return true }
        return false
    }
}

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
