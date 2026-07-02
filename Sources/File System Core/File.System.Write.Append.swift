//
//  File.System.Write.Append.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System.Write {
    /// Append data to existing files.
    public enum Append {}
}

// MARK: - Error (Union of Kernel Errors)

extension File.System.Write.Append {
    /// Errors that can occur during append operations.
    ///
    /// This is a union of the kernel errors that the append operation can produce.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on specific cases for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from open operation.
        case open(Kernel.File.Open.Error)
        /// Error from write operation.
        case write(Kernel.IO.Write.Error)
    }
}

// MARK: - Semantic Accessors

extension File.System.Write.Append.Error {
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
        case .open(let e):
            if case .path(.isDirectory) = e { return true }
            return false
        default:
            return false
        }
    }

    /// Returns `true` if the filesystem is read-only.
    public var isReadOnly: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isReadOnly { return true }
            return false
        default:
            return false
        }
    }

    /// Returns `true` if there's no space left on device.
    public var isNoSpace: Bool {
        switch self {
        case .open(let e):
            if case .platform(let p) = e, p.code.isNoSpace { return true }
            return false
        case .write(let e):
            if case .platform(let p) = e, p.code.isNoSpace { return true }
            return false
        }
    }
}

// MARK: - Core API

extension File.System.Write.Append {
    /// Appends bytes to a file.
    ///
    /// Creates the file if it doesn't exist.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to append.
    ///   - path: The file path.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public static func append(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing File.Path
    ) throws(File.System.Write.Append.Error) {
        // Open file for appending (create if not exists)
        // var instead of deferred-init let: workaround for compiler bug with
        // ~Copyable deferred-init let captured in non-escaping closure.
        var descriptor: Kernel.Descriptor = .invalid
        do {
            descriptor = try Kernel.File.Open.open(
                path: path.kernelPath,
                mode: .write,
                options: [.create, .append],
                permissions: Kernel.File.Permissions(rawValue: 0o644)
            )
        } catch {
            throw .open(error)
        }

        if bytes.count == 0 { return }

        // Write all bytes
        do throws(Kernel.IO.Write.Error) {
            try unsafe bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) throws(Kernel.IO.Write.Error) in
                try unsafe writeAll(descriptor, from: rawBuffer)
            }
        } catch {
            throw .write(error)
        }
    }

    /// Writes all bytes from a raw buffer, looping for partial writes with EINTR retry.
    private static func writeAll(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Kernel.IO.Write.Error) {
        var totalWritten = 0
        while totalWritten < buffer.count {
            let slice = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            do throws(Kernel.IO.Write.Error) {
                let written = try unsafe Kernel.IO.Write.write(descriptor, from: slice)
                if written > 0 {
                    totalWritten += written
                }
            } catch {
                // Check for EINTR (interrupted) - retry. POSIX vocabulary;
                // Windows syscalls are not interruptible in the signal sense.
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
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Append {
    /// Appends a Binary.Serializable value to a file.
    ///
    /// - Parameters:
    ///   - value: The serializable value to append.
    ///   - path: The file path.
    /// - Throws: `File.System.Write.Append.Error` on failure.
    public static func append<S: Binary.Serializable>(
        _ value: S,
        to path: borrowing File.Path
    ) throws(File.System.Write.Append.Error) {
        try S.withSerializedBytes(value) {
            (span: borrowing Swift.Span<Byte>) throws(File.System.Write.Append.Error) in
            try append(span, to: path)
        }
    }

}

// MARK: - CustomStringConvertible for Error

extension File.System.Write.Append.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .open(let error):
            return "Open failed: \(error)"
        case .write(let error):
            return "Write failed: \(error)"
        }
    }
}
