//
//  File.Directory.Contents.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Either_Primitives
import Kernel

extension File.Directory {
    /// List directory contents.
    public enum Contents {}
}

// MARK: - Convenience API (Allocating)

extension File.Directory.Contents {
    /// Lists the contents of a directory as an array.
    ///
    /// This is a convenience wrapper around `iterate(at:body:)` that collects
    /// entries into an array. Prefer `iterate` for zero-allocation iteration.
    ///
    /// - Parameter directory: The directory to list.
    /// - Returns: An array of directory entries.
    /// - Throws: `File.Directory.Contents.Error` on failure.
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
            // `E` is `Never` here, so the closure arm is uninhabited.
            throw error.value
        }
        return entries
    }
}

// MARK: - Core API (Callback-Based, Zero-Allocation)

extension File.Directory.Contents {
    /// Iterates over directory contents, calling a closure for each entry.
    ///
    /// This is the canonical directory listing API. It avoids allocating an array
    /// by yielding each entry to the callback. Use `Control.break` for early exit.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Non-throwing closure: `E` is `Never`, so the closure arm of the thrown
    /// // `Either` is uninhabited and `error.value` recovers the directory error.
    /// do throws(Either<File.Directory.Contents.Error, Never>) {
    ///     try File.Directory.Contents.iterate(at: directory) { entry in
    ///         print(entry.name)
    ///         return .continue
    ///     }
    /// } catch {
    ///     let failure: File.Directory.Contents.Error = error.value
    /// }
    ///
    /// // Throwing closure: both arms are inhabited.
    /// do throws(Either<File.Directory.Contents.Error, Decode.Error>) {
    ///     try File.Directory.Contents.iterate(at: directory) { entry in
    ///         try decode(entry)
    ///         return .continue
    ///     }
    /// } catch {
    ///     switch error {
    ///     case .left(let directoryFailure): ...
    ///     case .right(let closureFailure): ...
    ///     }
    /// }
    ///
    /// // When you just want an array, `list(at:)` absorbs the `Never` arm for you.
    /// let entries = try File.Directory.Contents.list(at: directory)
    /// ```
    ///
    /// A non-throwing closure infers `E` as `Never`, so the thrown type collapses
    /// to `Either<File.Directory.Contents.Error, Never>` and the closure arm is
    /// statically uninhabited — recover the directory error with `error.value`.
    ///
    /// - Parameters:
    ///   - directory: The directory to iterate.
    ///   - body: A closure called for each entry. Return `.continue` to keep iterating,
    ///           or `.break` to stop early.
    /// - Throws: `Either<Contents.Error, E>` — `.left` for directory failures,
    ///   `.right` if the closure throws.
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

// MARK: - Error Mapping

extension File.Directory.Contents {
    /// Maps Kernel.Directory.Error to File.Directory.Contents.Error.
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

        case .platform(let kernelError):
            let errno = kernelError.code.posix ?? Int32(kernelError.code.win32 ?? 0)
            return .readFailed(errno: errno, message: "\(kernelError)")
        }
    }
}

// MARK: - Type Mapping

extension File.Directory.Contents {
    /// Maps Kernel.File.Stats.Kind to File.Directory.Entry.Kind.
    private static func mapEntryType(
        _ kernelType: Kernel.File.Stats.Kind?,
        name: File.Name,
        parent: File.Path
    ) -> File.Directory.Entry.Kind {
        guard let kernelType else {
            // Type unknown (DT_UNKNOWN on some filesystems)
            // Fall back to lstat to determine type
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
            // Other link types (junction, mount point) treated as symlinks
            return .symbolicLink

        case .device, .fifo, .socket, .unknown:
            return .other
        }
    }

    /// Falls back to lstat when d_type is unknown.
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
