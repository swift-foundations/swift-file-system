public import Kernel

extension File.System {

    public enum Move {}
}

extension File.System.Move {

    public struct Options: Sendable {

        public var overwrite: Bool

        public init(overwrite: Bool = false) {
            self.overwrite = overwrite
        }
    }
}

extension File.System.Move {

    public enum Error: Swift.Error, Sendable {

        case destinationExists(File.Path)

        case rename(Kernel.File.Move.Error)

        case copy(File.System.Copy.Error)

        case cleanup(Kernel.File.Delete.Error)
    }
}

extension File.System.Move.Error {

    public var isSourceNotFound: Bool {
        switch self {
        case .destinationExists:
            return false

        case .rename(let e):
            return e == .notFound

        case .copy(let e):
            if case .sourceNotFound = e { return true }
            return false

        case .cleanup:
            return false
        }
    }

    public var isDestinationExists: Bool {
        switch self {
        case .destinationExists:
            return true

        case .rename:
            return false

        case .copy(let e):
            if case .destinationExists = e { return true }
            return false

        case .cleanup:
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .destinationExists:
            return false

        case .rename(let e):
            return e == .permission

        case .copy(let e):
            if case .permissionDenied = e { return true }
            return false

        case .cleanup(let e):
            if case .permission = e { return true }
            return false
        }
    }

    public var isCrossDevice: Bool {
        switch self {
        case .rename(let e):
            return e == .crossDevice

        default:
            return false
        }
    }

    public var isDirectory: Bool {
        switch self {
        case .rename(let e):
            return e == .isDirectory

        case .copy(let e):
            if case .isDirectory = e { return true }
            return false

        default:
            return false
        }
    }
}

extension File.System.Move {

    public static func move(
        from source: borrowing File.Path,
        to destination: borrowing File.Path,
        options: borrowing Options = .init()
    ) throws(Self.Error) {

        if !options.overwrite {
            let destExists: Bool
            do throws(Kernel.File.Stats.Error) {
                _ = try destination.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                    try Kernel.File.Stats.get(path: kernelPath)
                }
                destExists = true
            } catch {
                destExists = false
            }
            if destExists {
                throw .destinationExists(copy destination)
            }
        }

        do throws(Kernel.File.Move.Error) {
            try source.withKernelPath { sourceKernelPath throws(Kernel.File.Move.Error) in
                try destination.withKernelPath {
                    destinationKernelPath throws(Kernel.File.Move.Error) in
                    try Kernel.File.Move.move(from: sourceKernelPath, to: destinationKernelPath)
                }
            }
        } catch {

            if case .crossDevice = error {
                try copyAndDelete(from: source, to: destination, options: options)
                return
            }
            throw .rename(error)
        }
    }

    private static func copyAndDelete(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Self.Error) {

        let copyOptions = File.System.Copy.Options(
            overwrite: options.overwrite,
            copyAttributes: true,
            followSymlinks: true
        )

        do throws(File.System.Copy.Error) {
            try File.System.Copy.copy(from: source, to: destination, options: copyOptions)
        } catch {
            throw .copy(error)
        }

        do throws(Kernel.File.Delete.Error) {
            try source.withKernelPath { kernelPath throws(Kernel.File.Delete.Error) in
                try Kernel.File.Delete.delete(kernelPath)
            }
        } catch {
            throw .cleanup(error)
        }
    }

}

extension File.System.Move.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .destinationExists(let path):
            return "Destination already exists: \(path)"

        case .rename(let error):
            return "Rename failed: \(error)"

        case .copy(let error):
            return "Copy failed (cross-device): \(error)"

        case .cleanup(let error):
            return "Source cleanup failed after copy: \(error)"
        }
    }
}
