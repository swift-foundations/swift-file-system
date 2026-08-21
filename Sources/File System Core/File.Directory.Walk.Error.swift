extension File.Directory.Walk {

    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: Swift.String)
        case undecodableEntry(parent: File.Path, name: File.Name)
    }
}

extension File.Directory.Walk.Error {

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

    public var isUndecodableEntry: Bool {
        if case .undecodableEntry = self { return true }
        return false
    }
}

extension File.Directory.Walk.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"

        case .permissionDenied(let path):
            return "Permission denied: \(path)"

        case .notADirectory(let path):
            return "Not a directory: \(path)"

        case .walkFailed(let errno, let message):
            return "Walk failed: \(message) (errno=\(errno))"

        case .undecodableEntry(let parent, let name):
            return "Undecodable entry in \(parent): \(Swift.String(describing: name))"
        }
    }
}
