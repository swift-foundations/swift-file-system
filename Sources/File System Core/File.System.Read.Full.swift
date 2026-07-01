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
    /// // Process without allocation
    /// let checksum = try File.System.Read.Full.read(from: path) { span in
    ///     computeChecksum(span)
    /// }
    ///
    /// // Copy only when needed
    /// let bytes: [UInt8] = try File.System.Read.Full.read(from: path) { span in
    ///     Array(span)  // Explicit allocation
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: The path to the file to read.
    ///   - body: A closure that receives the file contents as a borrowed span.
    /// - Returns: The value returned by the closure.
    /// - Throws: `File.System.Read.Full.Error` on failure.
    public static func read<R>(
        from path: borrowing File.Path,
        body: (Swift.Span<Byte>) -> R
    ) throws(File.System.Read.Full.Error) -> R {
        // Open file for reading
        let descriptor: Kernel.Descriptor
        do {
            descriptor = try Kernel.File.Open.open(
                path: path.kernelPath,
                mode: .read,
                options: [],
                permissions: Kernel.File.Permissions(rawValue: 0)
            )
        } catch {
            throw .open(error)
        }

        // Get file stats to determine size and type
        let stats: Kernel.File.Stats
        do throws(Kernel.File.Stats.Error) {
            stats = try Kernel.File.Stats.get(descriptor: descriptor)
        } catch {
            throw .stat(error)
        }

        // Check if it's a directory
        if case .directory = stats.type {
            throw .isDirectory(copy path)
        }

        let fileSize = Int(stats.size.underlying)

        // Handle empty file
        if fileSize == 0 {
            let empty: [Byte] = []
            return body(empty.span)
        }

        // Read all bytes using pread for positional reads
        let buffer: [Byte]
        do throws(Kernel.IO.Read.Error) {
            buffer = try readAll(descriptor: descriptor, size: fileSize)
        } catch {
            throw .read(error)
        }

        return body(buffer.span)
    }

    /// Reads a file and passes its contents to a throwing closure as a borrowed span.
    ///
    /// - Parameters:
    ///   - path: The path to the file to read.
    ///   - body: A throwing closure that receives the file contents as a borrowed span.
    /// - Returns: The value returned by the closure.
    /// - Throws: `Either<Read.Full.Error, E>` — `.left` for read failures,
    ///   `.right` if the closure throws.
    public static func read<R, E: Swift.Error>(
        from path: borrowing File.Path,
        body: (Swift.Span<Byte>) throws(E) -> R
    ) throws(Either<File.System.Read.Full.Error, E>) -> R {
        var bodyError: E?
        let result: R?
        do throws(File.System.Read.Full.Error) {
            result = try read(from: path) { (span: Swift.Span<Byte>) -> R? in
                do throws(E) {
                    return try body(span)
                } catch {
                    bodyError = error
                    return nil
                }
            }
        } catch {
            throw .left(error)
        }
        if let error = bodyError {
            throw .right(error)
        }
        return result!
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
                if case .platform(let kernelError) = error,
                    kernelError.code == Error_Primitives.Error.Code.POSIX.EINTR
                {
                    continue
                }
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
