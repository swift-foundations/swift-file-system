extension File.Directory.Contents {

    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case readFailed(errno: Int32, message: Swift.String)
    }
}

extension File.Directory.Contents.Error {

    public var isNotFound: Bool {
        if case .pathNotFound = self { return true }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .permissionDenied = self { return true }
        return false
    }

    public var isNotADirectory: Bool {
        if case .notADirectory = self { return true }
        return false
    }
}

extension File.Directory.Contents.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"

        case .permissionDenied(let path):
            return "Permission denied: \(path)"

        case .notADirectory(let path):
            return "Not a directory: \(path)"

        case .readFailed(let errno, let message):
            return "Read failed: \(message) (errno=\(errno))"
        }
    }
}
