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
        do throws(File.Path.Error) {
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
                code: ._notFound,
                message: "Parent directory does not exist"
            )
        }

        // 2. Stat destination if it exists (for metadata preservation)
        let destStats = statIfExists(resolved)

        // 3. Create temp file with unique name. Extract the descriptor
        // into a plain local immediately: borrowed-Optional field
        // projections (tempFile.descriptor!) into throwing calls are the
        // §A23 ownership-verifier crash class on the Windows asserts
        // toolchain; borrows of a whole local value are not.
        var tempFile = try createTempFileWithRetry(
            in: parent,
            for: resolved
        )
        let tempPath = tempFile.path
        let descriptor = tempFile.descriptor.take()!
        phase = .writing

        defer {
            // CRITICAL: After renamedPublished, NEVER unlink destination!
            if phase < .renamedPublished {
                do throws(Kernel.File.Delete.Error) {
                    try Kernel.File.Delete.delete(tempPath.kernelPath)
                } catch {
                    // Best-effort cleanup; ignore failures.
                }
            }
        }

        // 4. Write all data
        do throws(File.System.Write.Error) {
            try File.System.Write.writeAll(bytes, to: descriptor)
        } catch { throw Self.Error(error) }

        // 5. Sync file to disk
        do throws(File.System.Write.Error) {
            try File.System.Write.syncFile(
                descriptor,
                durability: options.durability
            )
        } catch { throw Self.Error(error) }
        phase = .syncedFile

        // 6. Apply metadata from destination if requested
        if let stats = destStats {
            try applyMetadata(
                from: stats,
                to: descriptor,
                options: options
            )
        }

        // 7. Close file (required before rename on some systems)
        do throws(File.System.Write.Error) {
            try File.System.Write.closeFile(descriptor)
        } catch { throw Self.Error(error) }
        phase = .closed

        // 8. Atomic rename
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

        // 9. Sync directory to persist the rename
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

// MARK: - File Stats

extension File.System.Write.Atomic {
    private static func statIfExists(
        _ path: File.Path
    ) -> Kernel.File.Stats? {
        do throws(Kernel.File.Stats.Error) {
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
                    code: ._io,
                    message: "\(error)"
                )
            }
        }

        throw .tempFileCreationFailed(
            directory: parent,
            // `._exists` here is `Error_Primitives.Error.Code` (this file's synthesized code);
            // distinct from `File.System.Write.Error.exists` matched in the init above.
            code: ._exists,
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
