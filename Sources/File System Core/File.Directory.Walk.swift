import Either_Primitives
import Kernel

extension File.Directory {

    public struct Walk: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory {

    public var walk: Walk {
        Walk(path)
    }
}

extension File.Directory.Walk {

    public func callAsFunction(
        options: borrowing Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        do throws(Either<File.Directory.Walk.Error, Never>) {
            try iterate(options: options) { entry in
                entries.append(entry)
                return .continue
            }
        } catch {

            throw error.value
        }
        return entries
    }
}

extension File.Directory.Walk {

    public func iterate<E: Swift.Error>(
        options: borrowing Options = Options(),
        body: (File.Directory.Entry) throws(E) -> File.Directory.Contents.Control
    ) throws(Either<File.Directory.Walk.Error, E>) {
        var bodyError: E?
        var visited: Set<InodeKey> = []
        var stopped = false
        do throws(File.Directory.Walk.Error) {
            try Self.walkCallback(
                at: File.Directory(path),
                options: options,
                depth: 0,
                visited: &visited,
                stopped: &stopped,
                body: { entry in
                    do throws(E) {
                        return try body(entry)
                    } catch {
                        bodyError = error
                        return .break
                    }
                }
            )
        } catch {
            throw .left(error)
        }
        if let error = bodyError {
            throw .right(error)
        }
    }

    public func files(
        options: borrowing Options = Options(),
        body: (File) -> File.Directory.Contents.Control
    ) throws(File.Directory.Walk.Error) {
        do throws(Either<File.Directory.Walk.Error, Never>) {
            try iterate(options: options) { entry in
                guard entry.type == .file, let path = entry.pathIfValid else {
                    return .continue
                }
                return body(File(path))
            }
        } catch {

            throw error.value
        }
    }

    public func directories(
        options: borrowing Options = Options(),
        body: (File.Directory) -> File.Directory.Contents.Control
    ) throws(File.Directory.Walk.Error) {
        do throws(Either<File.Directory.Walk.Error, Never>) {
            try iterate(options: options) { entry in
                guard entry.type == .directory, let path = entry.pathIfValid else {
                    return .continue
                }
                return body(File.Directory(path))
            }
        } catch {

            throw error.value
        }
    }
}

extension File.Directory.Walk {
    @usableFromInline
    internal static func walkCallback(
        at directory: File.Directory,
        options: Options,
        depth: Int,
        visited: inout Set<InodeKey>,
        stopped: inout Bool,
        body: (File.Directory.Entry) -> File.Directory.Contents.Control
    ) throws(File.Directory.Walk.Error) {

        if stopped {
            return
        }

        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }

        if options.followSymlinks {
            if let key = getInodeKey(at: directory.path) {
                let (inserted, _) = visited.insert(key)
                if !inserted {
                    return
                }
            }
        }

        var walkError: File.Directory.Walk.Error?

        do throws(Either<File.Directory.Contents.Error, Never>) {
            try File.Directory.Contents.iterate(at: directory) { entry in

                if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                    return .continue
                }

                if let entryPath = entry.pathIfValid {

                    switch body(entry) {
                    case .continue:
                        break

                    case .break:
                        stopped = true
                        return .break
                    }

                    if entry.type == .directory {
                        let subdir = File.Directory(entryPath)
                        do throws(File.Directory.Walk.Error) {
                            try walkCallback(
                                at: subdir,
                                options: options,
                                depth: depth + 1,
                                visited: &visited,
                                stopped: &stopped,
                                body: body
                            )
                        } catch {
                            walkError = error
                            return .break
                        }
                        if stopped {
                            return .break
                        }
                    } else if entry.type == .symbolicLink && options.followSymlinks {
                        let info: File.System.Metadata.Info?
                        do throws(Kernel.File.Stats.Error) {
                            info = try File.System.Stat.info(at: entryPath)
                        } catch {
                            info = nil
                        }
                        if let info,
                            info.type == .directory
                        {
                            let subdir = File.Directory(entryPath)
                            do throws(File.Directory.Walk.Error) {
                                try walkCallback(
                                    at: subdir,
                                    options: options,
                                    depth: depth + 1,
                                    visited: &visited,
                                    stopped: &stopped,
                                    body: body
                                )
                            } catch {
                                walkError = error
                                return .break
                            }
                            if stopped {
                                return .break
                            }
                        }
                    }
                } else {

                    let context = Undecodable.Context(
                        parent: entry.parent,
                        name: entry.name,
                        type: entry.type,
                        depth: depth
                    )
                    switch options.onUndecodable(context) {
                    case .skip:
                        break

                    case .emit:
                        switch body(entry) {
                        case .continue:
                            break

                        case .break:
                            stopped = true
                            return .break
                        }

                    case .stopAndThrow:
                        walkError = .undecodableEntry(parent: entry.parent, name: entry.name)
                        return .break
                    }
                }

                return .continue
            }
        } catch {

            switch error.value {
            case .pathNotFound(let p):
                throw .pathNotFound(p)

            case .permissionDenied(let p):
                throw .permissionDenied(p)

            case .notADirectory(let p):
                throw .notADirectory(p)

            case .readFailed(let errno, let message):
                throw .walkFailed(errno: errno, message: message)
            }
        }

        if let error = walkError {
            throw error
        }
    }

}

extension File.Directory.Walk {

    @usableFromInline
    internal static func getInodeKey(at path: File.Path) -> InodeKey? {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: path)
        } catch {
            return nil
        }
        return InodeKey(device: info.device, inode: info.inode)
    }
}
