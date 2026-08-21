import Kernel
import Strings

extension File.System.Copy {

    public static func recursive(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init()
    ) throws(Error) {
        try copyRecursive(from: source, to: destination, options: options)
    }
}

extension File.System.Copy {

    @usableFromInline
    internal static func copyRecursive(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Error) {

        let sourceInfo: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            sourceInfo = try File.System.Stat.info(at: source)
        } catch {
            throw .sourceNotFound
        }

        guard sourceInfo.type == .directory else {
            try copy(from: source, to: destination, options: options)
            return
        }

        if File.System.Stat.exists(at: destination) {
            if !options.overwrite {
                throw .destinationExists
            }

            do throws(File.System.Delete.Error) {
                try File.System.Delete.delete(
                    at: destination,
                    recursive: true
                )
            } catch {
                throw .operation("Failed to remove existing destination: \(error)")
            }
        }

        do throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(at: destination)
        } catch {
            throw .operation("Failed to create destination directory: \(error)")
        }

        var success = false
        defer {
            if !success {

                do throws(File.System.Delete.Error) {
                    try File.System.Delete.delete(
                        at: destination,
                        recursive: true
                    )
                } catch {

                }
            }
        }

        if options.copyAttributes {
            copyDirectoryAttributes(from: source, to: destination)
        }

        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: File.Directory(source))
        } catch {
            throw mapContentsError(error, source: source)
        }

        for entry in entries {

            guard let sourcePath = entry.pathIfValid else {

                continue
            }

            let destPath: File.Path
            do throws(Paths.Path.Component.Error) {
                destPath = destination / (try entry.name.asPathComponent())
            } catch {

                continue
            }

            switch entry.type {
            case .file:
                try copy(from: sourcePath, to: destPath, options: options)

            case .directory:
                try copyRecursive(from: sourcePath, to: destPath, options: options)

            case .symbolicLink:
                if options.followSymlinks {

                    try copySymlinkTarget(
                        from: sourcePath,
                        to: destPath,
                        options: options
                    )
                } else {

                    try copySymlinkRecursive(from: sourcePath, to: destPath)
                }

            case .other:

                continue
            }
        }

        if options.copyAttributes {
            copyDirectoryTimestamps(from: source, to: destination)
        }

        success = true
    }

    private static func copySymlinkTarget(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Error) {

        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: source)
        } catch {

            throw .sourceNotFound
        }

        switch info.type {
        case .directory:
            try copyRecursive(from: source, to: destination, options: options)

        case .regular:
            try copy(from: source, to: destination, options: options)

        default:

            break
        }
    }
}

#if !os(Windows)
    extension File.System.Copy {

        private static func copySymlinkRecursive(
            from source: File.Path,
            to destination: File.Path
        ) throws(Error) {

            let target: Swift.String
            do throws(Kernel.Link.Symbolic.Error) {
                target = try source.withKernelPath {
                    sourceKernelPath throws(Kernel.Link.Symbolic.Error) in
                    let kernelString = try Kernel.Link.Symbolic.readTarget(at: sourceKernelPath)
                    return Swift.String(kernelString.view)
                }
            } catch {
                throw .operation("symlink read failed: \(error)")
            }

            do throws(Kernel.Link.Symbolic.Error) {
                let targetPath: File.Path
                do throws(File.Path.Error) {
                    targetPath = try File.Path(target)
                } catch {
                    throw Kernel.Link.Symbolic.Error.notFound
                }
                try targetPath.withKernelPath {
                    targetKernelPath throws(Kernel.Link.Symbolic.Error) in
                    try destination.withKernelPath {
                        destinationKernelPath throws(Kernel.Link.Symbolic.Error) in
                        try Kernel.Link.Symbolic.create(
                            target: targetKernelPath,
                            at: destinationKernelPath
                        )
                    }
                }
            } catch {
                throw .operation("symlink create failed: \(error)")
            }
        }
    }
#else
    extension File.System.Copy {

        private static func copySymlinkRecursive(
            from source: File.Path,
            to destination: File.Path
        ) throws(Error) {

            try copySymlinkTarget(
                from: source,
                to: destination,
                options: .init(followSymlinks: true)
            )
        }
    }
#endif

extension File.System.Copy {

    private static func copyDirectoryAttributes(
        from source: File.Path,
        to destination: File.Path
    ) {
        #if !os(Windows)

            let sourceInfo: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                sourceInfo = try File.System.Stat.info(at: source)
            } catch {
                return
            }

            do throws(Kernel.File.Attributes.Error) {
                let kernelPermissions = Kernel.File.Permissions(
                    rawValue: sourceInfo.permissions.rawValue
                )
                try destination.withKernelPath {
                    destinationKernelPath throws(Kernel.File.Attributes.Error) in
                    try Kernel.File.Attributes.set(kernelPermissions, at: destinationKernelPath)
                }
            } catch {

            }
        #endif
    }

    private static func copyDirectoryTimestamps(
        from source: File.Path,
        to destination: File.Path
    ) {
        #if !os(Windows)

            let sourceInfo: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                sourceInfo = try File.System.Stat.info(at: source)
            } catch {
                return
            }

            do throws(Kernel.File.Times.Error) {
                try destination.withKernelPath {
                    destinationKernelPath throws(Kernel.File.Times.Error) in
                    try Kernel.File.Times.set(
                        access: sourceInfo.accessTime,
                        modification: sourceInfo.modificationTime,
                        at: destinationKernelPath
                    )
                }
            } catch {

            }
        #endif
    }
}

extension File.System.Copy {

    private static func mapContentsError(
        _ error: File.Directory.Contents.Error,
        source: File.Path
    ) -> File.System.Copy.Error {
        switch error {
        case .pathNotFound:
            return .sourceNotFound

        case .permissionDenied:
            return .permissionDenied

        case .notADirectory:
            return .isDirectory

        case .readFailed(_, let message):
            return .operation("Directory read failed: \(message)")
        }
    }
}
