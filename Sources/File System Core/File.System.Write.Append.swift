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
        /// The write loop made no progress: `write()` returned `0` bytes
        /// for a non-empty buffer before `expected` bytes were written.
        case shortWrite(written: Int, expected: Int)
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

        case .shortWrite:
            return false
        }
    }
}

// MARK: - Write-Loop Progress

extension File.System.Write.Append {
    /// Advances the append write-loop's progress counter after one syscall
    /// attempt.
    ///
    /// This is the single decision point the append write loop uses: a
    /// syscall that reports `0` bytes written for a non-empty remaining
    /// region is always a typed failure — never silently ignored (which
    /// would spin the retry loop forever making no progress).
    ///
    /// - Parameters:
    ///   - totalWritten: Bytes written so far, before this syscall attempt.
    ///   - writtenThisCall: Bytes reported written by this syscall attempt.
    ///   - expected: Total bytes the loop is trying to write.
    /// - Returns: The updated `totalWritten`.
    /// - Throws: `.shortWrite(written:expected:)` if `writtenThisCall == 0`.
    @usableFromInline
    internal static func advance(
        totalWritten: Int,
        by writtenThisCall: Int,
        expected: Int
    ) throws(Self.Error) -> Int {
        guard writtenThisCall > 0 else {
            throw .shortWrite(written: totalWritten, expected: expected)
        }
        return totalWritten + writtenThisCall
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
    ) throws(Self.Error) {
        // Open file for appending (create if not exists)
        // var instead of deferred-init let: workaround for compiler bug with
        // ~Copyable deferred-init let captured in non-escaping closure.
        // WHEN TO REMOVE: once the underlying compiler bug is fixed upstream.
        // TRACKING: swift-file-system/HANDOFF.md follow-up item 4 (compiler-bug dossiers).
        var descriptor: Kernel.Descriptor = .invalid
        do throws(Kernel.File.Open.Error) {
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
        try unsafe bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) throws(Self.Error) in
            try unsafe writeAll(descriptor, from: rawBuffer)
        }
    }

    /// Writes all bytes from a raw buffer, looping for partial writes with EINTR retry.
    ///
    /// A `write()` call that returns `0` for a non-empty buffer is treated
    /// as a typed failure (`.shortWrite`) — never silently dropped (which
    /// would spin the `while` loop forever making no progress).
    private static func writeAll(
        _ descriptor: borrowing Kernel.Descriptor,
        from buffer: UnsafeRawBufferPointer
    ) throws(Self.Error) {
        var totalWritten = 0
        while totalWritten < buffer.count {
            let slice = unsafe UnsafeRawBufferPointer(
                start: buffer.baseAddress?.advanced(by: totalWritten),
                count: buffer.count - totalWritten
            )
            let written: Int
            do throws(Kernel.IO.Write.Error) {
                written = try unsafe Kernel.IO.Write.write(descriptor, from: slice)
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
                throw .write(error)
            }
            totalWritten = try Self.advance(totalWritten: totalWritten, by: written, expected: buffer.count)
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
    ) throws(Self.Error) {
        try S.withSerializedBytes(value) {
            (span: borrowing Swift.Span<Byte>) throws(Self.Error) in
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

        case .shortWrite(let written, let expected):
            return "Short write: wrote \(written) of \(expected) bytes, write() returned 0"
        }
    }
}
