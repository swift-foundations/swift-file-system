public import Kernel

extension File.System.Write.Atomic.Error {

    init(_ error: File.System.Write.Error) {
        switch error {
        case .sync(let msg):
            self = .syncFailed(code: ._io, message: msg)

        case .close(let msg):
            self = .closeFailed(code: ._io, message: msg)

        case .rename(let from, let to, let msg):
            self = .renameFailed(from: from, to: to, code: ._io, message: msg)

        case .exists(let path):
            self = .destinationExists(path: path)

        case .directory(let path, let msg):
            self = .directorySyncFailed(path: path, code: ._io, message: msg)

        case .write(let written, let expected, let msg):
            self = .writeFailed(
                bytesWritten: written,
                bytesExpected: expected,
                code: ._io,
                message: msg
            )

        case .random(let msg):
            self = .randomGenerationFailed(
                code: ._io,
                operation: "getrandom",
                message: msg
            )
        }
    }
}

extension File.System.Write.Atomic {

    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: borrowing Options = Options()
    ) throws(Error) {
        let pathString = Swift.String(path)
        let resolved: File.Path
        do throws(File.Path.Error) {
            resolved = try File.Path(pathString)
        } catch {
            throw .invalidPath(error)
        }
        try write(bytes, toPath: resolved, options: options)
    }

    internal static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        toPath resolved: File.Path,
        options: borrowing Options
    ) throws(Error) {
        typealias Phase = File.System.Write.Atomic.Commit.Phase

        var phase: Phase = .pending

        let (_, parent) = File.System.Write.resolvePaths(resolved)

        if !File.System.Write.fileExists(parent) {
            throw .parentVerificationFailed(
                path: parent,
                code: ._notFound,
                message: "Parent directory does not exist"
            )
        }

        let destStats = statIfExists(resolved)

        var tempFile = try createTempFileWithRetry(
            in: parent,
            for: resolved
        )
        let tempPath = tempFile.path
        let descriptor = tempFile.descriptor.take()!
        phase = .writing

        defer {

            if phase < .renamedPublished {
                do throws(Kernel.File.Delete.Error) {
                    try tempPath.withKernelPath { kernelPath throws(Kernel.File.Delete.Error) in
                        try Kernel.File.Delete.delete(kernelPath)
                    }
                } catch {

                }
            }
        }

        do throws(File.System.Write.Error) {
            try File.System.Write.writeAll(bytes, to: descriptor)
        } catch { throw Self.Error(error) }

        do throws(File.System.Write.Error) {
            try File.System.Write.syncFile(
                descriptor,
                durability: options.durability
            )
        } catch { throw Self.Error(error) }
        phase = .syncedFile

        if let stats = destStats {
            try applyMetadata(
                from: stats,
                to: descriptor,
                options: options
            )
        }

        do throws(File.System.Write.Error) {
            try File.System.Write.closeFile(descriptor)
        } catch { throw Self.Error(error) }
        phase = .closed

        switch options.strategy {
        case .replaceExisting:
            do throws(File.System.Write.Error) {
                try File.System.Write.atomicRename(
                    from: tempFile.path,
                    to: resolved
                )
            } catch { throw Self.Error(error) }

        case .noClobber:
            do throws(File.System.Write.Error) {
                try File.System.Write.atomicRenameNoClobber(
                    from: tempFile.path,
                    to: resolved
                )
            } catch { throw Self.Error(error) }
        }
        phase = .renamedPublished

        if options.durability == .full {
            phase = .directorySyncAttempted
            do throws(File.System.Write.Error) {
                try File.System.Write.syncDirectory(parent)
                phase = .syncedDirectory
            } catch {
                if case .directory(let path, let msg) = error {
                    throw .directorySyncFailedAfterCommit(
                        path: path,
                        code: ._io,
                        message: msg
                    )
                }
                throw Self.Error(error)
            }
        } else {
            phase = .syncedDirectory
        }
    }
}

extension File.System.Write.Atomic {
    private static func statIfExists(
        _ path: File.Path
    ) -> Kernel.File.Stats? {
        do throws(Kernel.File.Stats.Error) {
            return try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.lget(path: kernelPath)
            }
        } catch {
            return nil
        }
    }
}

extension File.System.Write.Atomic {

    private struct TempFile: ~Copyable, Sendable {
        var descriptor: Kernel.Descriptor?
        let path: File.Path
    }

    private static let maxTempFileAttempts = 64

    private static func createTempFileWithRetry(
        in parent: File.Path,
        for dest: File.Path
    ) throws(Error) -> TempFile {
        guard let baseName = File.System.Write.fileName(of: dest) else {
            throw .tempFileCreationFailed(
                directory: parent,
                code: ._invalid,
                message: "destination has no filename component"
            )
        }
        let pid = Kernel.Process.ID.current

        for attempt in 0..<maxTempFileAttempts {
            let random: Swift.String
            do throws(File.System.Write.Error) {
                random = try File.System.Write.randomToken(length: 12)
            } catch { throw Self.Error(error) }
            let tempComponent: File.Path.Component =
                ".\(baseName.string).atomic.\(pid).\(random).tmp"
            let tempPath = parent.appending(tempComponent)

            do throws(Kernel.File.Open.Error) {

                var fd: Kernel.Descriptor = .invalid
                try tempPath.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                    fd = try Kernel.File.Open.open(
                        path: kernelPath,
                        mode: .readWrite,
                        options: [.create, .exclusive],
                        permissions: .ownerReadWrite
                    )
                }
                return TempFile(descriptor: fd, path: tempPath)
            } catch {
                if case .path(.exists) = error,
                    attempt < maxTempFileAttempts - 1
                {
                    continue
                }
                throw .tempFileCreationFailed(
                    directory: parent,
                    code: ._io,
                    message: "\(error)"
                )
            }
        }

        throw .tempFileCreationFailed(
            directory: parent,

            code: ._exists,
            message: "Failed after \(maxTempFileAttempts) attempts"
        )
    }
}

extension File.System.Write.Atomic {
    private static func applyMetadata(
        from stats: Kernel.File.Stats,
        to descriptor: borrowing Kernel.Descriptor,
        options: borrowing Options
    ) throws(Error) {
        if options.preservation.contains(.permissions) {
            do throws(Kernel.File.Attributes.Error) {
                try Kernel.File.Attributes.set(
                    stats.permissions,
                    on: descriptor
                )
            } catch {
                let code: Error_Primitives.Error.Code
                switch error {
                case .platform(let e): code = e.code
                case .permission: code = ._accessDenied
                case .path: code = ._notFound
                case .io: code = ._io
                }
                throw .metadataPreservationFailed(
                    operation: "fchmod",
                    code: code,
                    message: "\(error)"
                )
            }
        }

        if case .preserve(let strict) = options.ownership {
            do throws(Kernel.File.Chown.Error) {
                try Kernel.File.Chown.fchown(
                    descriptor,
                    uid: stats.uid,
                    gid: stats.gid
                )
            } catch {
                if strict {
                    let code: Error_Primitives.Error.Code
                    switch error {
                    case .platform(let e): code = e.code
                    case .permission: code = ._accessDenied
                    case .path: code = ._notFound
                    case .io: code = ._io
                    }
                    throw .metadataPreservationFailed(
                        operation: "fchown",
                        code: code,
                        message: "\(error)"
                    )
                }
            }
        }

        if options.preservation.contains(.timestamps) {
            do throws(Kernel.File.Times.Error) {
                try Kernel.File.Times.set(
                    access: stats.accessTime,
                    modification: stats.modificationTime,
                    on: descriptor
                )
            } catch {
                throw .timestampPreservationFailed(error)
            }
        }

        _ = options.preservation.contains(.extendedAttributes)
        _ = options.preservation.contains(.acls)
    }
}
