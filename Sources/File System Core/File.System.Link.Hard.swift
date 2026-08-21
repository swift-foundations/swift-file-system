public import Kernel

extension File.System.Link {

    public enum Hard {}
}

extension File.System.Link.Hard {

    public enum Error: Swift.Error, Sendable {

        case link(Kernel.Link.Error)
    }
}

extension File.System.Link.Hard.Error {

    public var isSourceNotFound: Bool {
        if case .link(let e) = self {
            return e == .notFound
        }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .link(let e) = self {
            return e == .permission
        }
        return false
    }

    public var isAlreadyExists: Bool {
        if case .link(let e) = self {
            return e == .exists
        }
        return false
    }

    public var isCrossDevice: Bool {
        if case .link(let e) = self {
            return e == .crossDevice
        }
        return false
    }

    public var isDirectory: Bool {
        if case .link(let e) = self {
            return e == .isDirectory
        }
        return false
    }

    public var isReadOnly: Bool {
        if case .link(let e) = self {
            return e == .readOnly
        }
        return false
    }

    public var isTooManyLinks: Bool {
        if case .link(let e) = self {
            return e == .tooManyLinks
        }
        return false
    }
}

extension File.System.Link.Hard {

    public static func create(
        at path: borrowing File.Path,
        to existing: borrowing File.Path
    ) throws(Self.Error) {
        do throws(Kernel.Link.Error) {
            try path.withKernelPath { pathKernelPath throws(Kernel.Link.Error) in
                try existing.withKernelPath { existingKernelPath throws(Kernel.Link.Error) in
                    try Kernel.Link.create(at: pathKernelPath, to: existingKernelPath)
                }
            }
        } catch {
            throw .link(error)
        }
    }
}

extension File.System.Link.Hard.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .link(let error):
            return "Hard link creation failed: \(error)"
        }
    }
}
