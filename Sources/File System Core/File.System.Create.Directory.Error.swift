public import Kernel

extension File.System.Create.Directory {

    public enum Error: Swift.Error, Equatable, Sendable {

        case mkdir(Kernel.Directory.Create.Error)
    }
}

extension File.System.Create.Directory.Error {

    public var isAlreadyExists: Bool {
        if case .mkdir(let e) = self {
            return e == .exists
        }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .mkdir(let e) = self {
            return e == .permission
        }
        return false
    }

    public var isParentNotFound: Bool {
        if case .mkdir(let e) = self {
            return e == .notFound || e == .notDirectory
        }
        return false
    }

    public var isReadOnly: Bool {
        if case .mkdir(let e) = self {
            return e == .readOnly
        }
        return false
    }

    public var isNoSpace: Bool {
        if case .mkdir(let e) = self {
            return e == .noSpace
        }
        return false
    }
}

extension File.System.Create.Directory.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .mkdir(let error):
            return "Directory creation failed: \(error)"
        }
    }
}
