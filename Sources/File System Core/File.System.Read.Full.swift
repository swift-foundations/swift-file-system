//
//  File.System.Read.Full.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary_Primitives
import Either_Primitives
public import Kernel

extension File.System.Read {
    /// Read entire file contents into memory.
    public enum Full {}
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Read.Full {
    /// Errors that can occur during full file read operations.
    ///
    /// This is a union of the kernel errors that the read operation can produce.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from open operation.
        case open(Kernel.File.Open.Error)
        /// Error from stat operation.
        case stat(Kernel.File.Stats.Error)
        /// Error from read operation.
        case read(Kernel.IO.Read.Error)
        /// Path is a directory, not a file.
        case isDirectory(File.Path)
    }
}

// MARK: - Semantic Accessors

extension File.System.Read.Full.Error {
    /// Returns `true` if the file was not found.
    public var isNotFound: Bool {
        switch self {
        case .open(let e):
            if case .path(.notFound) = e { return true }
            return false

        default:
            return false
        }
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        default:
            return false
        }
    }

    /// Returns `true` if the path is a directory.
    public var isDirectory: Bool {
        switch self {
        case .isDirectory:
            return true

        case .open(let e):
            if case .path(.isDirectory) = e { return true }
            return false

        default:
            return false
        }
    }

    /// Returns `true` if too many files are open.
    public var isTooManyOpenFiles: Bool {
        switch self {
        case .open(let e):
            if case .handle(.limit) = e { return true }
            return false

        default:
            return false
        }
    }
}

// MARK: - Core API (Callback-Based, Zero-Copy)

extension File.System.Read.Full {
    /// Reads a file and passes its contents to a closure as a borrowed span.
    ///
    /// This is the canonical read API. The closure receives a `Swift.Span<Byte>`
    /// that borrows directly from an internal buffer. Callers who need to keep
    /// the data must copy it inside the closure.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Non-throwing closure: `E` is `Never`, so the closure arm of the thrown
    /// // `Either` is uninhabited and `error.value` recovers the read error.
    /// do throws(Either<File.System.Read.Full.Error, Never>) {
    ///     let checksum = try File.System.Read.Full.read(from: path) { span in
    ///         computeChecksum(span)
    ///     }
    /// } catch {
    ///     let failure: File.System.Read.Full.Error = error.value
    /// }
    ///
    /// // Throwing closure: both arms are inhabited.
    /// do throws(Either<File.System.Read.Full.Error, Decode.Error>) {
    ///     let value = try File.System.Read.Full.read(from: path) { span in
    ///         try decode(span)
    ///     }
    /// } catch {
    ///     switch error {
    ///     case .left(let readFailure): ...
    ///     case .right(let closureFailure): ...
    ///     }
    /// }
    /// ```
    ///
    /// A non-throwing closure infers `E` as `Never`, so the thrown type collapses
    /// to `Either<File.System.Read.Full.Error, Never>` and the closure arm is
    /// statically uninhabited — recover the read error with `error.value`.
    ///
    /// - Parameters:
    ///   - path: The path to the file to read.
    ///   - body: A closure that receives the file contents as a borrowed span.
    /// - Returns: The value returned by the closure.
    /// - Throws: `Either<Read.Full.Error, E>` — `.left` for read failures,
    ///   `.right` if the closure throws.
    public static func read<R, E: Swift.Error>(
        from path: borrowing File.Path,
        body: (Swift.Span<Byte>) throws(E) -> R
    ) throws(Either<File.System.Read.Full.Error, E>) -> R {
        // Open file for reading
        // Non-optional `var` storage, not a closure return: `Kernel.Descriptor`
        // is `~Copyable`, and `withKernelPath`'s generic `R` requires Copyable,
        // so the opened descriptor cannot flow out as the closure's result.
        var descriptor: Kernel.Descriptor = .invalid
        do throws(Kernel.File.Open.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.File.Open.Error) in
                descriptor = try Kernel.File.Open.open(
                    path: kernelPath,
                    mode: .read,
                    options: [],
                    permissions: Kernel.File.Permissions(rawValue: 0)
                )
            }
        } catch {
            throw .left(.open(error))
        }

        // Get file stats to determine size and type
        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try Kernel.File.Stats.get(descriptor: descriptor)
        } catch {
            throw .left(.stat(error))
        }

        // Check if it's a directory
        if case .directory = stats.type {
            throw .left(.isDirectory(copy path))
        }

        let fileSize = Int(stats.size.underlying)

        // Handle empty file
        if fileSize == 0 {
            let empty: [Byte] = []
            do throws(E) {
                return try body(empty.span)
            } catch {
                throw .right(error)
            }
        }

        // Read all bytes using pread for positional reads
        let buffer: [Byte]
        do throws(Kernel.IO.Read.Error) {
            buffer = try readAll(descriptor: descriptor, size: fileSize)
        } catch {
            throw .left(.read(error))
        }

        do throws(E) {
            return try body(buffer.span)
        } catch {
            throw .right(error)
        }
    }

}

// MARK: - Internal

extension File.System.Read.Full {
    /// Reads all bytes from a descriptor using positional reads.
    private static func readAll(
        descriptor: borrowing Kernel.Descriptor,
        size: Int
    ) throws(Kernel.IO.Read.Error) -> [Byte] {
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 1)
        defer { unsafe buffer.deallocate() }

        var totalRead = 0
        while totalRead < size {
            let slice = unsafe UnsafeMutableRawBufferPointer(
                start: buffer.baseAddress!.advanced(by: totalRead),
                count: size - totalRead
            )
            do throws(Kernel.IO.Read.Error) {
                let bytesRead = try unsafe Kernel.IO.Read.pread(
                    descriptor,
                    into: slice,
                    at: Kernel.File.Offset(Int64(totalRead))
                )
                guard bytesRead > 0 else { break }
                totalRead += bytesRead
            } catch {
                // EINTR retry is POSIX vocabulary; Windows syscalls are
                // not interruptible in the signal sense.
                #if !os(Windows)
                    if case .platform(let kernelError) = error,
                        kernelError.code == Error_Primitives.Error.Code.POSIX.EINTR
                    {
                        continue
                    }
                #endif
                throw error
            }
        }

        // Rebind the raw bytes to `Byte` (Byte is @frozen, single UInt8 stored
        // property — layout-identical to UInt8, so bindMemory is sound here).
        let typedBuf = unsafe buffer.bindMemory(to: Byte.self)
        return unsafe Array(UnsafeBufferPointer<Byte>(start: typedBuf.baseAddress, count: totalRead))
    }
}

// MARK: - CustomStringConvertible for Error

extension File.System.Read.Full.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .open(let error):
            return "Open failed: \(error)"

        case .stat(let error):
            return "Stat failed: \(error)"

        case .read(let error):
            return "Read failed: \(error)"

        case .isDirectory(let path):
            return "Is a directory: \(path)"
        }
    }
}
