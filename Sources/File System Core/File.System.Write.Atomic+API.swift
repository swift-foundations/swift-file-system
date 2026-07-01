// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

// MARK: - Error Mapping

extension File.System.Write.Atomic.Error {
    /// Creates an Atomic error from a shared write error.
    init(_ error: File.System.Write.Error) {
        switch error {
        case .sync(let msg):
            self = .syncFailed(code: .POSIX.EIO, message: msg)
        case .close(let msg):
            self = .closeFailed(code: .POSIX.EIO, message: msg)
        case .rename(let from, let to, let msg):
            self = .renameFailed(from: from, to: to, code: .POSIX.EIO, message: msg)
        case .exists(let path):
            self = .destinationExists(path: path)
        case .directory(let path, let msg):
            self = .directorySyncFailed(path: path, code: .POSIX.EIO, message: msg)
        case .write(let written, let expected, let msg):
            self = .writeFailed(
                bytesWritten: written,
                bytesExpected: expected,
                code: .POSIX.EIO,
                message: msg
            )
        case .random(let msg):
            self = .randomGenerationFailed(
                code: .POSIX.EIO,
                operation: "getrandom",
                message: msg
            )
        }
    }
}

// MARK: - Core API

extension File.System.Write.Atomic {
    /// Atomically writes bytes to a file path.
    ///
    /// This is the core primitive - all other write operations compose on top of this.
    ///
    /// ## Guarantees
    /// - Either the file exists with complete contents, or the original state is preserved
    /// - On success, data is synced to physical storage (survives power loss)
    /// - Safe to call concurrently for different paths
    ///
    /// ## Requirements
    /// - Parent directory must exist and be writable
    ///
    /// - Parameters:
    ///   - bytes: The data to write (borrowed, zero-copy)
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: borrowing Options = Options()
    ) throws(Error) {
        let pathString = Swift.String(path)
        let resolved: File.Path
        do {
            resolved = try File.Path(pathString)
        } catch {
            throw .invalidPath(error)
        }
        try write(bytes, toPath: resolved, options: options)
    }

    /// Internal entry point that works with a validated File.Path.
    internal static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        toPath resolved: File.Path,
        options: borrowing Options
    ) throws(Error) {
        typealias Phase = File.System.Write.Atomic.Commit.Phase

        var phase: Phase = .pending

        // 1. Resolve parent
        let (_, parent) = File.System.Write.resolvePaths(resolved)

        if !File.System.Write.fileExists(parent) {
            throw .parentVerificationFailed(
                path: parent,
                code: .POSIX.ENOENT,
                message: "Parent directory does not exist"
            )
        }

        // 2. Stat destination if it exists (for metadata preservation)
        let destStats = statIfExists(resolved)

        // 3. Create temp file with unique name
        var tempFile = try createTempFileWithRetry(
            in: parent,
            for: resolved
        )
        phase = .writing

        defer {
            // CRITICAL: After renamedPublished, NEVER unlink destination!
            // Descriptor closes via deinit when tempFile drops (if not already taken).
            if phase < .renamedPublished {
                try? Kernel.File.Delete.delete(tempFile.path.kernelPath)
            }
        }

        // 4. Write all data
        do {
            try File.System.Write.writeAll(bytes, to: tempFile.descriptor!)
        } catch { throw Error(error) }

        // 5. Sync file to disk
        do {
            try File.System.Write.syncFile(
                tempFile.descriptor!,
                durability: options.durability
            )
        } catch { throw Error(error) }
        phase = .syncedFile

        // 6. Apply metadata from destination if requested
        if let stats = destStats {
            try applyMetadata(
                from: stats,
                to: tempFile.descriptor!,
                options: options
            )
        }

        // 7. Close file (required before rename on some systems)
        do throws(File.System.Write.Error) {
            try File.System.Write.closeFile(tempFile.descriptor.take()!)
        } catch { throw Error(error) }
        phase = .closed

        // 8. Atomic rename
        switch options.strategy {
        case .replaceExisting:
            do {
                try File.System.Write.atomicRename(
                    from: tempFile.path,
                    to: resolved
                )
            } catch { throw Error(error) }
        case .noClobber:
            do {
                try File.System.Write.atomicRenameNoClobber(
                    from: tempFile.path,
                    to: resolved
                )
            } catch { throw Error(error) }
        }
        phase = .renamedPublished

        // 9. Sync directory to persist the rename
        if options.durability == .full {
            phase = .directorySyncAttempted
            do {
                try File.System.Write.syncDirectory(parent)
                phase = .syncedDirectory
            } catch {
                if case .directory(let path, let msg) = error {
                    throw .directorySyncFailedAfterCommit(
                        path: path,
                        code: .POSIX.EIO,
                        message: msg
                    )
                }
                throw Error(error)
            }
        } else {
            phase = .syncedDirectory
        }
    }
}

// MARK: - File Stats

extension File.System.Write.Atomic {
    private static func statIfExists(
        _ path: File.Path
    ) -> Kernel.File.Stats? {
        do {
            return try Kernel.File.Stats.lget(path: path.kernelPath)
        } catch {
            return nil
        }
    }
}

// MARK: - Temp File Creation

extension File.System.Write.Atomic {
    /// Temp file descriptor + path, returned from `createTempFileWithRetry`.
    /// `~Copyable` because it owns the `Kernel.Descriptor`.
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
                code: .POSIX.EINVAL,
                message: "destination has no filename component"
            )
        }
        let pid = Kernel.Process.ID.current

        for attempt in 0..<maxTempFileAttempts {
            let random: Swift.String
            do {
                random = try File.System.Write.randomToken(length: 12)
            } catch { throw Error(error) }
            let tempComponent: File.Path.Component =
                ".\(baseName.string).atomic.\(pid).\(random).tmp"
            let tempPath = parent.appending(tempComponent)

            do {
                let fd = try Kernel.File.Open.open(
                    path: tempPath.kernelPath,
                    mode: .readWrite,
                    options: [.create, .exclusive],
                    permissions: .ownerReadWrite
                )
                return TempFile(descriptor: fd, path: tempPath)
            } catch {
                if case .path(.exists) = error,
                    attempt < maxTempFileAttempts - 1
                {
                    continue
                }
                throw .tempFileCreationFailed(
                    directory: parent,
                    code: .POSIX.EIO,
                    message: "\(error)"
                )
            }
        }

        throw .tempFileCreationFailed(
            directory: parent,
            code: .EEXIST,
            message: "Failed after \(maxTempFileAttempts) attempts"
        )
    }
}

// MARK: - Metadata Preservation

extension File.System.Write.Atomic {
    private static func applyMetadata(
        from stats: Kernel.File.Stats,
        to descriptor: borrowing Kernel.Descriptor,
        options: borrowing Options
    ) throws(Error) {
        if options.preservation.contains(.permissions) {
            do {
                try Kernel.File.Attributes.set(
                    stats.permissions,
                    on: descriptor
                )
            } catch let error {
                let code: Error_Primitives.Error.Code
                switch error {
                case .platform(let e): code = e.code
                case .permission: code = .POSIX.EACCES
                case .path: code = .POSIX.ENOENT
                case .io: code = .POSIX.EIO
                }
                throw .metadataPreservationFailed(
                    operation: "fchmod",
                    code: code,
                    message: "\(error)"
                )
            }
        }

        if case .preserve(let strict) = options.ownership {
            do {
                try Kernel.File.Chown.fchown(
                    descriptor,
                    uid: stats.uid,
                    gid: stats.gid
                )
            } catch let error {
                if strict {
                    let code: Error_Primitives.Error.Code
                    switch error {
                    case .platform(let e): code = e.code
                    case .permission: code = .POSIX.EACCES
                    case .path: code = .POSIX.ENOENT
                    case .io: code = .POSIX.EIO
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
            do {
                try Kernel.File.Times.set(
                    access: stats.accessTime,
                    modification: stats.modificationTime,
                    on: descriptor
                )
            } catch let error {
                throw .timestampPreservationFailed(error)
            }
        }

        _ = options.preservation.contains(.extendedAttributes)
        _ = options.preservation.contains(.acls)
    }
}
