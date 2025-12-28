// File.System.Write.Streaming.swift
// Streaming/chunked file writing with optional atomic guarantees
//
// This module provides memory-efficient file writes by processing data in chunks.
// When atomic mode is enabled (default), it uses the same temp-file pattern as
// File.System.Write.Atomic to ensure crash-safety.

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    internal import WinSDK
#endif

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
    ///
    /// ## Windows Note
    ///
    /// Streaming writes deny all file sharing during the write operation.
    /// This is the safest default for data integrity but may cause:
    /// - Antivirus scanner interference (`ERROR_ACCESS_DENIED`)
    /// - File indexer conflicts
    /// - Inability to read file while writing
    ///
    /// If concurrent read access is required during writes, a different API
    /// with explicit share mode control would be needed.
    public enum Streaming {
    }
}

// MARK: - Core API

extension File.System.Write.Streaming {
    /// Writes a sequence of byte chunks to a file path.
    ///
    /// Memory-efficient for large files - processes one chunk at a time.
    /// Internally converts each chunk to Span for zero-copy writes.
    ///
    /// ## Performance Note
    ///
    /// This is a **convenience-grade** API. If you are allocating chunks in a loop,
    /// consider using the **performance-grade** `write(to:using:fill:)` overload instead,
    /// which accepts a reusable buffer and guarantees no allocations in the hot loop.
    ///
    /// ## Atomic Mode (default)
    /// - Writes to a temporary file in the same directory
    /// - Syncs temp file according to durability setting
    /// - Atomically renames on completion
    /// - Syncs directory to persist the rename
    /// - Either complete new file or original state preserved on crash
    ///
    /// ## Direct Mode
    /// - Writes directly to destination
    /// - Faster but partial writes possible on crash
    ///
    /// - Parameters:
    ///   - chunks: Sequence of owned byte arrays to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write<Chunks: Sequence>(
        _ chunks: Chunks,
        to path: File.Path,
        options: Options = Options()
    ) throws(File.System.Write.Streaming.Error) where Chunks.Element == [UInt8] {
        #if os(Windows)
            try Windows.write(chunks, to: String(path), options: options)
        #else
            try POSIX.write(chunks, to: String(path), options: options)
        #endif
    }
}

// MARK: - Single Write Overloads (Layer 1)
//
// These accept a single buffer and write it without requiring Sequence.
// They route through the same atomic/direct machinery as the streaming API.

extension File.System.Write.Streaming {
    /// Writes a single byte array to a file path.
    ///
    /// Routes through the multi-phase API (open, write, commit) without
    /// wrapping in an outer sequence array.
    ///
    /// - Parameters:
    ///   - bytes: Bytes to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: [UInt8],
        to path: File.Path,
        options: Options = Options()
    ) throws(File.System.Write.Streaming.Error) {
        #if os(Windows)
            try write([bytes], to: path, options: options)
        #else
            let context = try POSIX.open(path: path, options: options)
            do {
                try POSIX.write(chunk: bytes.span, to: context)
                try POSIX.commit(context)
            } catch {
                POSIX.cleanup(context)
                throw error
            }
        #endif
    }

    /// Writes a byte slice to a file path (zero-copy when contiguous).
    ///
    /// Uses contiguous storage directly to avoid allocations. If the slice is not
    /// contiguous (rare), copies to a temporary array.
    ///
    /// - Parameters:
    ///   - bytes: Byte slice to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: ArraySlice<UInt8>,
        to path: File.Path,
        options: Options = Options()
    ) throws(File.System.Write.Streaming.Error) {
        #if os(Windows)
            try write(Array(bytes), to: path, options: options)
        #else
            // Try to use contiguous storage directly (zero-copy path)
            // Capture error because withContiguousStorageIfAvailable has untyped throws
            var capturedError: File.System.Write.Streaming.Error? = nil

            let wasContiguous = bytes.withContiguousStorageIfAvailable { buffer -> Bool in
                do throws(File.System.Write.Streaming.Error) {
                    let context = try POSIX.open(path: path, options: options)
                    var succeeded = false
                    defer {
                        if !succeeded {
                            POSIX.cleanup(context)
                        }
                    }
                    let rawBuffer = UnsafeRawBufferPointer(buffer)
                    try POSIX.writeRaw(chunk: rawBuffer, to: context)
                    try POSIX.commit(context)
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

            // Non-contiguous (rare) - copy once and use [UInt8] overload
            try write(Array(bytes), to: path, options: options)
        #endif
    }

    /// Writes a span of bytes to a file path (zero-copy).
    ///
    /// This is the ideal single-write API - no allocations, direct syscalls.
    /// Routes through the multi-phase API (open, write, commit) for a single span.
    ///
    /// - Parameters:
    ///   - bytes: Span of bytes to write
    ///   - path: Destination file path
    ///   - options: Write options
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    @inlinable
    public static func write(
        _ bytes: borrowing Span<UInt8>,
        to path: File.Path,
        options: Options = Options()
    ) throws(File.System.Write.Streaming.Error) {
        #if os(Windows)
            try write(Array(bytes), to: path, options: options)
        #else
            let context = try POSIX.open(path: path, options: options)
            do {
                try POSIX.write(chunk: bytes, to: context)
                try POSIX.commit(context)
            } catch {
                POSIX.cleanup(context)
                throw error
            }
        #endif
    }
}

// MARK: - Reusable-Buffer Streaming (Layer 2)
//
// Performance-grade streaming that encodes "preallocated buffer reuse" as the default.
// These APIs make the fast path obvious and unavoidable.

extension File.System.Write.Streaming {
    /// Streams data to a file using a caller-owned reusable buffer.
    ///
    /// This is the **performance-grade** streaming API. It guarantees no allocations
    /// in the write hot loop by requiring the caller to provide a fixed-capacity buffer.
    ///
    /// ## Performance Contract
    /// - The buffer is reused across all iterations (no per-chunk allocations)
    /// - `fill` writes into the buffer's existing storage and returns bytes written
    /// - Returning `0` signals completion
    ///
    /// ## Usage
    /// ```swift
    /// var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    /// var offset = 0
    /// try File.System.Write.Streaming.write(to: path, using: &buffer) { buf in
    ///     let bytesToWrite = min(buf.count, totalSize - offset)
    ///     if bytesToWrite == 0 { return 0 }
    ///     // Fill buf[0..<bytesToWrite] with data
    ///     offset += bytesToWrite
    ///     return bytesToWrite
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - path: Destination file path
    ///   - options: Write options
    ///   - buffer: Caller-owned buffer (pre-sized to desired chunk size)
    ///   - fill: Closure that fills the buffer and returns number of valid bytes.
    ///           Return 0 to signal completion.
    /// - Throws: `File.System.Write.Streaming.Error` on failure
    public static func write(
        to path: File.Path,
        options: Options = Options(),
        using buffer: inout [UInt8],
        fill: (inout [UInt8]) throws -> Int
    ) throws(File.System.Write.Streaming.Error) {
        #if os(Windows)
            // Windows implementation
            try Windows.writeWithBuffer(to: String(path), options: options, buffer: &buffer, fill: fill)
        #else
            try POSIX.writeWithBuffer(to: String(path), options: options, buffer: &buffer, fill: fill)
        #endif
    }
}

// MARK: - Internal Helpers

extension File.System.Write.Streaming {
    @usableFromInline
    static func errorMessage(for errno: Int32) -> String {
        #if os(Windows)
            return "error \(errno)"
        #else
            if let cString = strerror(errno) {
                return String(cString: cString)
            }
            return "error \(errno)"
        #endif
    }
}
