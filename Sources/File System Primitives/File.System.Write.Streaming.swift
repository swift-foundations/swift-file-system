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
    public import WinSDK
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
            try WindowsStreaming.write(chunks, to: String(path), options: options)
        #else
            try POSIXStreaming.write(chunks, to: String(path), options: options)
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
