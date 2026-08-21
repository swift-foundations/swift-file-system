public import Kernel

extension File.System {

    public enum Delete {}
}

extension File.System.Delete {

    public struct Options: Sendable {
        public init() {}
    }
}

extension File.System.Delete {

    public enum Error: Swift.Error, Sendable {

        case stat(Kernel.File.Stats.Error)

        case unlink(Kernel.File.Delete.Error)

        case rmdir(Kernel.Directory.Remove.Error)

        case directory(Kernel.Directory.Error)
    }
}

extension File.System.Delete.Error {

    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .unlink(let e):
            if case .notFound = e { return true }
            return false

        case .rmdir(let e):
            return e == .notFound

        case .directory(let e):
            return e == .notFound
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .unlink(let e):
            if case .permission = e { return true }
            return false

        case .rmdir(let e):
            return e == .permission

        case .directory(let e):
            return e == .permission
        }
    }

    public var isDirectory: Bool {
        switch self {
        case .unlink(let e):
            if case .isDirectory = e { return true }
            return false

        default:
            return false
        }
    }

    public var isDirectoryNotEmpty: Bool {
        switch self {
        case .rmdir(let e):
            return e == .notEmpty

        default:
            return false
        }
    }
}

extension File.System.Delete {

    public static func delete(
        at path: borrowing File.Path,
        recursive: Bool = false
    ) throws(Error) {

        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try lstat(path)
        } catch {
            throw .stat(error)
        }

        if case .link = stats.type {

            try unlink(at: path)
            return
        }

        let isDirectory = stats.type == .directory

        if isDirectory {
            if recursive {
                try deleteRecursive(at: path)
            } else {

                try rmdir(at: path)
            }
        } else {

            try unlink(at: path)
        }
    }

    @usableFromInline
    internal static func lstat(
        _ path: File.Path
    ) throws(Kernel.File.Stats.Error) -> Kernel.File.Stats {
        try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
            try Kernel.File.Stats.lget(path: kernelPath)
        }
    }

    @usableFromInline
    internal static func unlink(at path: File.Path) throws(Error) {
        do throws(Kernel.File.Delete.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.File.Delete.Error) in
                try Kernel.File.Delete.delete(kernelPath)
            }
        } catch {
            throw .unlink(error)
        }
    }

    @usableFromInline
    internal static func rmdir(at path: File.Path) throws(Error) {
        do throws(Kernel.Directory.Remove.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.Directory.Remove.Error) in
                try Kernel.Directory.Remove.remove(kernelPath)
            }
        } catch {
            throw .rmdir(error)
        }
    }

    @usableFromInline
    internal static func deleteRecursive(
        at path: File.Path
    ) throws(Error) {

        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try path.withKernelPath { kernelPath throws(Kernel.Directory.Error) in
                try Kernel.Directory.open(at: kernelPath)
            }
        } catch {
            throw .directory(error)
        }
        defer { stream.close() }

        while true {
            let entry: Kernel.Directory.Entry?
            do throws(Kernel.Directory.Error) {
                entry = try stream.next()
            } catch {
                throw .directory(error)
            }

            guard let entry else {
                break
            }

            if entry.isDotOrDotDot {
                continue
            }

            let component: File.Path.Component
            do throws(Paths.Path.Component.Error) {
                component = try File.Name(from: entry).asPathComponent()
            } catch {

                continue
            }
            let childPath = path / component

            if case .directory = entry.type {
                try deleteRecursive(at: childPath)
            } else {
                try unlink(at: childPath)
            }
        }

        try rmdir(at: path)
    }
}
