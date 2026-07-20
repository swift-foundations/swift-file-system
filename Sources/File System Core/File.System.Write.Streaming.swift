// File.System.Write.Streaming.swift
// Streaming/chunked file writing with optional atomic guarantees
//
// This module provides memory-efficient file writes by processing data in chunks.
// Delegates to File.System.Write.Streaming for the platform-specific implementation.

public import Kernel

extension File.System.Write {
    /// Streaming/chunked file writing with optional atomic guarantees.
    ///
    /// Memory-efficient for large files - only holds one chunk at a time.
    ///
    /// ## Usage
    /// ```swift
    /// // Atomic streaming write (crash-safe, default)
    /// try File.System.Write.Streaming.write(chunks, to: path)
    ///
    /// // Direct streaming write (faster, no crash-safety)
    /// try File.System.Write.Streaming.write(chunks, to: path, options: .init(commit: .direct()))
    /// ```
    ///
    /// ## Performance Note
    /// For optimal performance, provide chunks of 64KB–1MB. Smaller chunks work
    /// correctly but with higher overhead due to syscall frequency.
    public enum Streaming {}
}

// MARK: - Core API

extension File.System.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write<Chunks: Swift.Sequence>(
        _ chunks: Chunks,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) where Chunks.Element == [Byte] {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(chunks, to: kernelPath, options: options)
        }
    }
}

// MARK: - Single Write Overloads

extension File.System.Write.Streaming {
    /// Writes a single byte array to a file path.
    ///
    /// - Parameters:
    ///   - bytes: Bytes to write
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: [Byte],
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(bytes, to: kernelPath, options: options)
        }
    }

    /// Writes a byte slice to a file path (zero-copy when contiguous).
    ///
    /// - Parameters:
    ///   - bytes: Byte slice to write
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: ArraySlice<Byte>,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)

        // Try to use contiguous storage directly (zero-copy path)
        var capturedError: Self.Error? = nil

        let wasContiguous = unsafe bytes.withContiguousStorageIfAvailable { buffer -> Bool in
            do throws(Error) {
                // Non-optional-turned-`Optional` + `take()` once: `Context` is
                // `~Copyable`, and `withKernelPath`'s generic `R` requires
                // Copyable, so the opened context cannot flow out as the
                // closure's result directly (unlike `Kernel.Descriptor`,
                // `Context` has no `.invalid` sentinel to pre-seed a `var`).
                var contextStorage: Context? = nil
                try path.withKernelPath { kernelPath throws(Error) in
                    contextStorage = try Self.open(path: kernelPath, options: options)
                }
                let context = contextStorage.take()!
                var succeeded = false
                defer {
                    if !succeeded {
                        Self.cleanup(context)
                    }
                }
                let rawBuffer = UnsafeRawBufferPointer(buffer)
                try unsafe Self.write(chunk: rawBuffer, to: context)
                try Self.commit(context)
                succeeded = true
            } catch {
                capturedError = error
            }
            return true
        }

        if let error = capturedError {
            throw error
        }

        if wasContiguous != nil {
            return
        }

        // Non-contiguous (rare) - copy once
        // Parent already ensured above, pass false to avoid redundant check
        try write(Array(bytes), to: path, options: options)
    }

    /// Writes a span of bytes to a file path (zero-copy).
    ///
    /// - Parameters:
    ///   - bytes: Span of bytes to write
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(bytes, to: kernelPath, options: options)
        }
    }
}

// MARK: - Reusable-Buffer Streaming

extension File.System.Write.Streaming {
    /// Streams data to a file using a caller-owned reusable buffer.
    ///
    /// This is the **performance-grade** streaming API. It guarantees no allocations
    /// in the write hot loop by requiring the caller to provide a fixed-capacity buffer.
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    ///   - buffer: Caller-owned buffer (pre-sized to desired chunk size)
    ///   - fill: Closure that fills the buffer and returns number of valid bytes.
    ///           Return 0 to signal completion.
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write<E: Swift.Error>(
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false,
        using buffer: inout [Byte],
        fill: (inout [Byte]) throws(E) -> Int
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try path.withKernelPath { kernelPath throws(Error) in
            try Self.write(to: kernelPath, options: options, using: &buffer, fill: fill)
        }
    }
}

// MARK: - Multi-Phase API

extension File.System.Write.Streaming {
    /// Opens a file for multi-phase streaming write.
    ///
    /// Returns a context that can be used for subsequent write(chunk:) and commit calls.
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (commit policy, durability)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Returns: A context for subsequent write and commit calls
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func open(
        path: borrowing File.Path,
        options: Options,
        createIntermediates: Bool = false
    ) throws(Error) -> Context {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        // Non-optional-turned-`Optional` + `take()` once: `Context` is
        // `~Copyable`, and `withKernelPath`'s generic `R` requires Copyable,
        // so the opened context cannot flow out as the closure's result
        // directly.
        var contextStorage: Context? = nil
        try path.withKernelPath { kernelPath throws(Error) in
            contextStorage = try Self.open(path: kernelPath, options: options)
        }
        return contextStorage.take()!
    }

}

// MARK: - Parent Directory

extension File.System.Write.Streaming {
    @usableFromInline
    internal static func ensureParent(
        for path: borrowing File.Path,
        createIntermediates: Bool
    ) throws(Error) {
        guard createIntermediates else { return }
        let parent = path.parentOrSelf
        do throws(File.System.Parent.Check.Error) {
            try File.System.Parent.Check.verify(parent, createIntermediates: true)
        } catch {
            throw .parentVerificationFailed(
                path: parent,
                code: ._notFound,
                message: "\(error)"
            )
        }
    }
}
