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

extension File.System.Write.Streaming.Error {
    /// Creates a Streaming error from a shared write error.
    init(_ error: File.System.Write.Error) {
        switch error {
        case .sync(let msg):
            self = .syncFailed(code: ._io, message: msg)

        case .close(let msg):
            self = .closeFailed(code: ._io, message: msg)

        case .rename(let from, let to, let msg):
            self = .renameFailed(
                from: from,
                to: to,
                code: ._io,
                message: msg
            )

        case .exists(let path):
            self = .destinationExists(path: path)

        case .directory(let path, let msg):
            self = .directorySyncFailed(
                path: path,
                code: ._io,
                message: msg
            )

        case .write(let written, _, let msg):
            self = .writeFailed(
                bytesWritten: written,
                code: ._io,
                message: msg
            )

        case .random(let msg):
            self = .randomGenerationFailed(
                code: ._io,
                message: msg
            )
        }
    }
}

// MARK: - Core Streaming Write API

extension File.System.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    public static func write<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: Options = Options()
    ) throws(Error) where Chunks.Element == [Byte] {
        let context = try open(path: path, options: options)

        do throws(Error) {
            for chunk in chunks {
                try write(chunk: chunk.span, to: context)
            }
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }

    /// Writes a single byte array to a file path.
    @inlinable
    public static func write(
        _ bytes: [Byte],
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: Options = Options()
    ) throws(Error) {
        let context = try open(path: path, options: options)
        do throws(Error) {
            try write(chunk: bytes.span, to: context)
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }

    /// Writes a span of bytes to a file path (zero-copy).
    @inlinable
    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: Options = Options()
    ) throws(Error) {
        let context = try open(path: path, options: options)
        do {
            try write(chunk: bytes, to: context)
            try commit(context)
        } catch {
            cleanup(context)
            throw error
        }
    }
}

// MARK: - Reusable-Buffer Streaming API

extension File.System.Write.Streaming {
    /// Streams data to a file using a caller-owned reusable buffer.
    ///
    /// This is the **performance-grade** streaming API. It guarantees no allocations
    /// in the write hot loop by requiring the caller to provide a fixed-capacity buffer.
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options
    ///   - buffer: Caller-owned buffer (pre-sized to desired chunk size)
    ///   - fill: Closure that fills the buffer and returns number of valid bytes.
    ///           Return 0 to signal completion.
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write<E: Swift.Error>(
        to path: borrowing Path_Primitives.Path.Borrowed,
        options: Options = Options(),
        using buffer: inout [Byte],
        fill: (inout [Byte]) throws(E) -> Int
    ) throws(Error) {
        let context = try open(path: path, options: options)
        var writeError: Self.Error? = nil

        defer {
            if writeError != nil {
                cleanup(context)
            }
        }

        while true {
            let bytesProduced: Int
            do throws(E) {
                bytesProduced = try fill(&buffer)
            } catch {
                writeError = .userError(
                    message: Swift.String(describing: error)
                )
                throw writeError!
            }

            if bytesProduced == 0 {
                break
            }

            guard bytesProduced <= buffer.count else {
                writeError = .invalidFillResult(
                    produced: bytesProduced,
                    capacity: buffer.count
                )
                throw writeError!
            }

            // Route through the borrowing Context method (via the static
            // wrapper), not a direct `context.descriptor!` projection: the
            // §A23 structural fix — projecting the @guaranteed field out of
            // the borrowed ~Copyable Context lets CopyPropagation shorten
            // the borrow to end before the consuming call, aborting the SIL
            // ownership verifier ("Found outside of lifetime use?!").
            do throws(Error) {
                try unsafe buffer.withUnsafeBufferPointer { ptr throws(Error) in
                    guard let base = ptr.baseAddress else { return }
                    try unsafe write(
                        chunk: UnsafeRawBufferPointer(
                            start: base,
                            count: bytesProduced
                        ),
                        to: context
                    )
                }
            } catch let error {
                writeError = error
                throw writeError!
            }
        }

        do {
            try commit(context)
        } catch {
            writeError = error
            throw error
        }
    }
}

// MARK: - Multi-Phase API

extension File.System.Write.Streaming {
    /// Opens a file for multi-phase streaming write.
    public static func open(
        path: borrowing Path_Primitives.Path.Borrowed,
        options: Options
    ) throws(Error) -> Context {
        let pathString = Swift.String(path)
        let resolvedPath: File.Path
        do {
            resolvedPath = try File.Path(pathString)
        } catch {
            throw .invalidPath(error)
        }
        return try open(path: resolvedPath, options: options)
    }

    @usableFromInline
    internal static func open(
        path resolvedPath: File.Path,
        options: Options
    ) throws(Error) -> Context {
        let (_, parent) = File.System.Write.resolvePaths(resolvedPath)

        if !File.System.Write.fileExists(parent) {
            throw .parentVerificationFailed(
                path: parent,
                code: ._notFound,
                message: "Parent directory does not exist"
            )
        }

        switch options.commit {
        case .atomic(let atomicOptions):
            let tempPath = try generateTempPath(
                in: parent,
                for: resolvedPath
            )
            let fd = try createFile(at: tempPath, exclusive: true)
            return Context(
                descriptor: fd,
                tempPath: tempPath,
                resolvedPath: resolvedPath,
                parentPath: parent,
                durability: atomicOptions.durability,
                isAtomic: true,
                strategy: atomicOptions.strategy
            )

        case .direct(let directOptions):
            if case .create = directOptions.strategy {
                if File.System.Write.fileExists(resolvedPath) {
                    throw .destinationExists(path: resolvedPath)
                }
            }
            let fd = try createFile(
                at: resolvedPath,
                exclusive: directOptions.strategy == .create
            )
            return Context(
                descriptor: fd,
                tempPath: nil,
                resolvedPath: resolvedPath,
                parentPath: parent,
                durability: directOptions.durability,
                isAtomic: false,
                strategy: nil
            )
        }
    }

    /// Writes a chunk to an open streaming context.
    public static func write(
        chunk span: borrowing Swift.Span<Byte>,
        to context: borrowing Context
    ) throws(Error) {
        do {
            try context.write(chunk: span)
        } catch { throw Self.Error(error) }
    }

    /// Writes a raw buffer chunk to an open streaming context.
    ///
    /// Distinguished from the `Swift.Span<Byte>` overload by parameter type.
    public static func write(
        chunk buffer: UnsafeRawBufferPointer,
        to context: borrowing Context
    ) throws(Error) {
        do {
            try context.write(chunk: buffer)
        } catch { throw Self.Error(error) }
    }

    /// Commits a streaming write, syncing and performing the atomic
    /// rename if needed. Descriptor closes via deinit when context drops.
    public static func commit(
        _ context: borrowing Context
    ) throws(Error) {
        do {
            try context.sync()
        } catch { throw Self.Error(error) }

        if context.isAtomic, let tempPath = context.tempPath {
            switch context.strategy {
            case .replaceExisting, .none:
                do {
                    try File.System.Write.atomicRename(
                        from: tempPath,
                        to: context.resolvedPath
                    )
                } catch { throw Self.Error(error) }

            case .noClobber:
                do {
                    try File.System.Write.atomicRenameNoClobber(
                        from: tempPath,
                        to: context.resolvedPath
                    )
                } catch { throw Self.Error(error) }
            }

            if context.durability == .full {
                do {
                    try File.System.Write.syncDirectory(context.parentPath)
                } catch {
                    if case .directory(let path, let msg) = error {
                        throw Self.Error.directorySyncFailedAfterCommit(
                            path: path,
                            code: ._io,
                            message: msg
                        )
                    }
                    throw Self.Error(error)
                }
            }
        }
    }

    /// Cleans up a failed streaming write.
    /// Descriptor closes via deinit when context drops.
    public static func cleanup(_ context: borrowing Context) {
        if let tempPath = context.tempPath {
            do throws(Kernel.File.Delete.Error) {
                try Kernel.File.Delete.delete(tempPath.kernelPath)
            } catch {
                // Best-effort cleanup; ignore failures.
            }
        }
    }
}

// MARK: - Context Descriptor Operations

// These `borrowing` methods house the descriptor-consuming throwing helper calls
// so that `self`'s borrow and the `descriptor` field projection sit inside one
// function-level `@guaranteed` scope. The static API maps the helper error at the
// call boundary (`do { try context.<op>() } catch { throw Error(error) }`), where
// the wrapped call takes the whole `context` as `@guaranteed self`.
//
// STRUCTURAL FIX for the SIL ownership-verifier abort catalogued at §A23
// (Issues/swift-issue-file-system-streaming-write-ownership): Swift 6.3.x
// CopyPropagation shortens the borrow of a `borrowing ~Copyable` Context to end
// before a call consuming its `@guaranteed descriptor` field, aborting `-O`
// ("Found outside of lifetime use?!"). Empirically the abort fires on a plain
// `apply` as well as a `try_apply`, so it is the field-projected borrow scope —
// not the typed-throws continuation — that must be eliminated: a whole-function
// `@guaranteed self` parameter has no shortenable nested borrow scope. Correct on
// all toolchains, so no compiler gate is needed.
extension File.System.Write.Streaming.Context {
    /// Writes a span chunk to this context's descriptor.
    borrowing func write(
        chunk span: borrowing Swift.Span<Byte>
    ) throws(File.System.Write.Error) {
        try File.System.Write.writeAll(span, to: descriptor)
    }

    /// Writes a raw buffer chunk to this context's descriptor.
    borrowing func write(
        chunk buffer: UnsafeRawBufferPointer
    ) throws(File.System.Write.Error) {
        try unsafe File.System.Write.writeAllRaw(buffer, to: descriptor)
    }

    /// Syncs this context's descriptor according to its durability setting.
    borrowing func sync() throws(File.System.Write.Error) {
        try File.System.Write.syncFile(descriptor, durability: durability)
    }
}

// MARK: - File Operations (Streaming-Specific)

extension File.System.Write.Streaming {
    private static func createFile(
        at path: File.Path,
        exclusive: Bool
    ) throws(Error) -> Kernel.Descriptor {
        var options: Kernel.File.Open.Options = [.create, .execClose]
        if exclusive {
            options.insert(.exclusive)
        } else {
            options.insert(.truncate)
        }

        do {
            return try Kernel.File.Open.open(
                path: path.kernelPath,
                mode: .write,
                options: options,
                permissions: .standard
            )
        } catch {
            throw .fileCreationFailed(
                path: path,
                code: ._notFound,
                message: "open failed: \(error)"
            )
        }
    }

    private static func generateTempPath(
        in parent: File.Path,
        for dest: File.Path
    ) throws(Error) -> File.Path {
        guard let baseName = File.System.Write.fileName(of: dest) else {
            throw .fileCreationFailed(
                path: dest,
                code: ._invalid,
                message: "destination has no filename component"
            )
        }
        let random: Swift.String
        do {
            random = try File.System.Write.randomToken(length: 12)
        } catch { throw Self.Error(error) }
        let tempComponent: File.Path.Component =
            ".\(baseName.string).streaming.\(random).tmp"
        return parent.appending(tempComponent)
    }
}
