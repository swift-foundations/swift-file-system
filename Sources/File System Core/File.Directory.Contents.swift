import Either
import Kernel

extension File.Directory {

    public enum Contents {}
}

extension File.Directory.Contents {

    public static func list(
        at directory: borrowing File.Directory
    ) throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        do throws(Either<File.Directory.Contents.Error, Never>) {
            try iterate(at: directory) { entry in
                entries.append(entry)
                return .continue
            }
        } catch {

            throw error.value
        }
        return entries
    }
}

extension File.Directory.Contents {

    public static func iterate<E: Swift.Error>(
        at directory: borrowing File.Directory,
        body: (File.Directory.Entry) throws(E) -> Control
    ) throws(Either<File.Directory.Contents.Error, E>) {
        let path = directory.path

        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try path.withKernelPath { kernelPath throws(Kernel.Directory.Error) in
                try Kernel.Directory.open(at: kernelPath)
            }
        } catch {
            throw .left(mapKernelError(error, path: path))
        }
        defer { stream.close() }

        while true {
            let kernelEntry: Kernel.Directory.Entry?
            do throws(Kernel.Directory.Error) {
                kernelEntry = try stream.next()
            } catch {
                throw .left(mapKernelError(error, path: path))
            }

            guard let kernelEntry else {
                break
            }

            if kernelEntry.isDotOrDotDot {
                continue
            }

            let name = File.Name(from: kernelEntry)
            let entryType = mapEntryType(kernelEntry.type, name: name, parent: path)
            let entry = File.Directory.Entry(name: name, parent: path, type: entryType)

            let control: Control
            do throws(E) {
                control = try body(entry)
            } catch {
                throw .right(error)
            }

            switch control {
            case .continue:
                continue

            case .break:
                return
            }
        }
    }
}

extension File.Directory.Contents {

    internal static func mapKernelError(
        _ error: Kernel.Directory.Error,
        path: File.Path
    ) -> File.Directory.Contents.Error {
        switch error {
        case .notFound:
            return .pathNotFound(path)

        case .permission:
            return .permissionDenied(path)

        case .notDirectory:
            return .notADirectory(path)

        case .tooManyOpenFiles:
            return .readFailed(errno: 0, message: "Too many open files")

        case .io:
            return .readFailed(errno: 0, message: "I/O error")

        case .closed:

            return .readFailed(errno: 0, message: "Directory stream used after close")

        case .platform(let kernelError):
            let errno = kernelError.code.posix ?? Int32(kernelError.code.win32 ?? 0)
            return .readFailed(errno: errno, message: "\(kernelError)")
        }
    }
}

extension File.Directory.Contents {

    private static func mapEntryType(
        _ kernelType: Kernel.File.Stats.Kind?,
        name: File.Name,
        parent: File.Path
    ) -> File.Directory.Entry.Kind {
        guard let kernelType else {

            return lstatEntryType(name: name, parent: parent)
        }

        switch kernelType {
        case .regular:
            return .file

        case .directory:
            return .directory

        case .link(.symbolic):
            return .symbolicLink

        case .link:

            return .symbolicLink

        case .device, .fifo, .socket, .unknown:
            return .other
        }
    }

    private static func lstatEntryType(
        name: File.Name,
        parent: File.Path
    ) -> File.Directory.Entry.Kind {
        guard
            let entryPath = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .other
            ).pathIfValid
        else {
            return .other
        }

        do throws(Kernel.File.Stats.Error) {
            let stats = try entryPath.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.lget(path: kernelPath)
            }
            switch stats.type {
            case .regular:
                return .file

            case .directory:
                return .directory

            case .link(.symbolic), .link:
                return .symbolicLink

            default:
                return .other
            }
        } catch {
            return .other
        }
    }
}
