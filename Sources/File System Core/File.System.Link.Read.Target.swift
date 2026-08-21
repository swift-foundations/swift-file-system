public import Kernel
import Strings

extension File.System.Link.Read {

    public enum Target {}
}

extension File.System.Link.Read.Target {

    public enum Error: Swift.Error, Sendable {

        case stat(Kernel.File.Stats.Error)

        case readlink(Kernel.Link.Symbolic.Error)

        case notASymlink(File.Path)

        case invalidTargetPath(Swift.String)
    }
}

extension File.System.Link.Read.Target.Error {

    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .readlink(let e):
            return e == .notFound

        default:
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .readlink(let e):
            return e == .permission

        default:
            return false
        }
    }

    public var isNotASymlink: Bool {
        switch self {
        case .notASymlink:
            return true

        case .readlink(let e):
            return e == .notSymbolicLink

        default:
            return false
        }
    }
}

extension File.System.Link.Read.Target {

    public static func target(
        of path: borrowing File.Path
    ) throws(Self.Error) -> File.Path {

        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.lget(path: kernelPath)
            }
        } catch {
            throw .stat(error)
        }

        guard case .link = stats.type else {
            throw .notASymlink(copy path)
        }

        let targetString: Swift.String
        do throws(Kernel.Link.Symbolic.Error) {
            targetString = try path.withKernelPath {
                kernelPath throws(Kernel.Link.Symbolic.Error) in
                let kernelString = try Kernel.Link.Symbolic.readTarget(at: kernelPath)
                return Swift.String(kernelString.view)
            }
        } catch {
            throw .readlink(error)
        }

        let targetPath: File.Path
        do throws(File.Path.Error) {
            targetPath = try File.Path(targetString)
        } catch {
            throw .invalidTargetPath(targetString)
        }
        return targetPath
    }
}

extension File.System.Link.Read.Target.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"

        case .readlink(let error):
            return "Readlink failed: \(error)"

        case .notASymlink(let path):
            return "Not a symbolic link: \(path)"

        case .invalidTargetPath(let target):
            return "Invalid target path: \(target)"
        }
    }
}
