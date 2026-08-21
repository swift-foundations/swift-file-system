public import Kernel

extension File.System.Link {

    public enum Symbolic {}
}

extension File.System.Link.Symbolic {

    public enum Error: Swift.Error, Sendable {

        case symlink(Kernel.Link.Symbolic.Error)
    }
}

extension File.System.Link.Symbolic.Error {

    public var isAlreadyExists: Bool {
        if case .symlink(let e) = self {
            return e == .exists
        }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .symlink(let e) = self {
            return e == .permission
        }
        return false
    }

    public var isParentNotFound: Bool {
        if case .symlink(let e) = self {
            return e == .notFound || e == .notDirectory
        }
        return false
    }

    public var isReadOnly: Bool {
        if case .symlink(let e) = self {
            return e == .readOnly
        }
        return false
    }

    public var isNoSpace: Bool {
        if case .symlink(let e) = self {
            return e == .noSpace
        }
        return false
    }
}

extension File.System.Link.Symbolic {

    public static func create(
        at path: borrowing File.Path,
        pointingTo target: borrowing File.Path
    ) throws(Self.Error) {
        do throws(Kernel.Link.Symbolic.Error) {
            try target.withKernelPath { targetKernelPath throws(Kernel.Link.Symbolic.Error) in
                try path.withKernelPath { pathKernelPath throws(Kernel.Link.Symbolic.Error) in
                    try Kernel.Link.Symbolic.create(target: targetKernelPath, at: pathKernelPath)
                }
            }
        } catch {
            throw .symlink(error)
        }
    }
}

extension File.System.Link.Symbolic.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .symlink(let error):
            return "Symlink creation failed: \(error)"
        }
    }
}
