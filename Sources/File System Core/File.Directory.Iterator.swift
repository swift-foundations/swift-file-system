public import Kernel

extension File.Directory {

    public struct Iterator: ~Copyable {
        private var _stream: Kernel.Directory.Stream?
        private let _basePath: File.Path

        private init(stream: Kernel.Directory.Stream, basePath: File.Path) {
            self._stream = stream
            self._basePath = basePath
        }

        deinit {
            _stream?.close()
        }
    }
}

extension File.Directory.Iterator {

    public enum Error: Swift.Error, Sendable {

        case directory(Kernel.Directory.Error)
    }
}

extension File.Directory.Iterator.Error {

    public var isNotFound: Bool {
        if case .directory(let e) = self {
            return e == .notFound
        }
        return false
    }

    public var isPermissionDenied: Bool {
        if case .directory(let e) = self {
            return e == .permission
        }
        return false
    }

    public var isNotADirectory: Bool {
        if case .directory(let e) = self {
            return e == .notDirectory
        }
        return false
    }

    public var isTooManyOpenFiles: Bool {
        if case .directory(let e) = self {
            return e == .tooManyOpenFiles
        }
        return false
    }
}

extension File.Directory.Iterator {

    public static func open(
        at directory: File.Directory
    ) throws(Self.Error) -> File.Directory.Iterator {
        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try directory.path.withKernelPath {
                kernelPath throws(Kernel.Directory.Error) in
                try Kernel.Directory.open(at: kernelPath)
            }
        } catch {
            throw .directory(error)
        }

        return File.Directory.Iterator(stream: stream, basePath: directory.path)
    }

    public mutating func next() throws(Self.Error) -> File.Directory.Entry? {
        guard let stream = _stream else {
            return nil
        }

        while true {
            let kernelEntry: Kernel.Directory.Entry?
            do throws(Kernel.Directory.Error) {
                kernelEntry = try stream.next()
            } catch {
                throw .directory(error)
            }

            guard let entry = kernelEntry else {
                return nil
            }

            let name = File.Name(from: entry)

            if name.isDotOrDotDot {
                continue
            }

            let entryType: File.Directory.Entry.Kind
            if let type = entry.type {
                switch type {
                case .regular:
                    entryType = .file

                case .directory:
                    entryType = .directory

                case .link(.symbolic):
                    entryType = .symbolicLink

                default:
                    entryType = .other
                }
            } else {

                entryType = statForType(name: name)
            }

            return File.Directory.Entry(name: name, parent: _basePath, type: entryType)
        }
    }

    public consuming func close() {
        _stream?.close()
        _stream = nil
    }

    private func statForType(name: File.Name) -> File.Directory.Entry.Kind {
        guard
            let entryPath = File.Directory.Entry(
                name: name,
                parent: _basePath,
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

extension File.Directory.Iterator.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .directory(let error):
            return "Directory iteration failed: \(error)"
        }
    }
}
