//
//  File.Handle.Error.swift
//  swift-file-system
//

public import Kernel

// MARK: - Error (Union of Kernel Errors)

extension File.Handle {
    /// Errors that can occur during `File.Handle` write operations.
    ///
    /// This wraps the kernel write error and adds a case the kernel error
    /// alone cannot represent: a short (partial, zero-byte) write. Every
    /// `File.Handle` write loop treats `write()` returning `0` for a
    /// non-empty buffer as a typed failure — never silent truncation, never
    /// an unbounded retry loop.
    public enum Error: Swift.Error, Sendable {
        /// Error from the underlying kernel write syscall.
        case write(Kernel.IO.Write.Error)
        /// The write loop made no progress: `write()` returned `0` bytes
        /// for a non-empty buffer before `expected` bytes were written.
        case shortWrite(written: Int, expected: Int)
    }
}

// MARK: - Semantic Accessors

extension File.Handle.Error {
    /// Returns `true` if the error indicates a short (zero-progress) write.
    public var isShortWrite: Bool {
        if case .shortWrite = self { return true }
        return false
    }
}

// MARK: - Write-Loop Progress

extension File.Handle {
    /// Advances a write-loop's progress counter after one syscall attempt.
    ///
    /// This is the single decision point every `File.Handle` write loop
    /// (`writeAll`, `pwriteAll`) shares: a syscall that reports `0` bytes
    /// written for a non-empty remaining region is always a typed failure —
    /// never a silent early return (data loss) and never a reason to retry
    /// without bound (an infinite loop).
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
    ) throws(File.Handle.Error) -> Int {
        guard writtenThisCall > 0 else {
            throw .shortWrite(written: totalWritten, expected: expected)
        }
        return totalWritten + writtenThisCall
    }
}

// MARK: - CustomStringConvertible

extension File.Handle.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .write(let error):
            return "Write failed: \(error)"

        case .shortWrite(let written, let expected):
            return "Short write: wrote \(written) of \(expected) bytes, write() returned 0"
        }
    }
}
