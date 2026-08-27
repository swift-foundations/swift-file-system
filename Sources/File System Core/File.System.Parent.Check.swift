public import Kernel

extension File.System {

    public enum Parent {}
}

extension File.System.Parent {

    public enum Check {}
}

extension File.System.Parent.Check {

    public static func verify(
        _ path: File.Path,
        createIntermediates: Bool
    ) throws(Self.Error) {
        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
        } catch {

            switch error {
            case .platform(let platformError):
                let code = platformError.code
                if code.isPermissionDenied {
                    throw .accessDenied(path: path)
                } else if code.isNotDirectory {
                    throw .notDirectory(path: path)
                } else if code.isNotFound {
                    if createIntermediates {
                        try createParent(at: path)
                        return
                    }
                    throw .missing(path: path)
                } else if code.isInvalidPath {
                    throw .invalidPath(path: path)
                } else if code.isNetworkNotFound {
                    throw .networkPathNotFound(path: path)
                } else {
                    throw .statFailed(path: path, operation: .stat, code: code)
                }

            case .handle:
                throw .statFailed(path: path, operation: .stat, code: .posix(0))
            }
        }

        guard case .directory = stats.type else {
            throw .notDirectory(path: path)
        }
    }

    private static func createParent(at path: File.Path) throws(Self.Error) {
        do throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(
                at: path,
                createIntermediates: true
            )
        } catch {
            throw .creationFailed(path: path, underlying: error)
        }
    }
}

extension File.System.Parent.Check {

    public enum Operation: Swift.String, Sendable {
        case stat = "stat(parent)"
        case getFileAttributes = "GetFileAttributesW(parent)"
    }
}

extension File.System.Parent.Check {

    public enum Error: Swift.Error, Equatable, Sendable {

        case accessDenied(path: File.Path)

        case notDirectory(path: File.Path)

        case missing(path: File.Path)

        case statFailed(path: File.Path, operation: Operation, code: Error.Error.Code)

        case invalidPath(path: File.Path)

        case networkPathNotFound(path: File.Path)

        case creationFailed(path: File.Path, underlying: File.System.Create.Directory.Error)
    }
}

extension File.System.Parent.Check.Error {

    public var isNotFound: Bool {
        if case .missing = self { return true }
        if case .creationFailed(_, let e) = self, e.isParentNotFound { return true }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .accessDenied = self { return true }
        if case .creationFailed(_, let e) = self, e.isPermissionDenied { return true }
        return false
    }

    public var isNotDirectory: Bool {
        if case .notDirectory = self { return true }
        return false
    }

    public var isInvalidPath: Bool {
        if case .invalidPath = self { return true }
        return false
    }

    public var isNetworkPathNotFound: Bool {
        if case .networkPathNotFound = self { return true }
        return false
    }

    public var isCreationFailed: Bool {
        if case .creationFailed = self { return true }
        return false
    }
}

extension File.System.Parent.Check.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .accessDenied(let path):
            return "Access denied to parent directory: \(path)"

        case .notDirectory(let path):
            return "Path component is not a directory: \(path)"

        case .missing(let path):
            return "Parent directory not found: \(path)"

        case .statFailed(let path, let operation, let code):
            return "\(operation.rawValue) failed for \(path): \(code)"

        case .invalidPath(let path):
            return "Invalid path: \(path)"

        case .networkPathNotFound(let path):
            return "Network path not found: \(path)"

        case .creationFailed(let path, let underlying):
            return "Failed to create parent directory \(path): \(underlying)"
        }
    }
}
