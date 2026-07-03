// File.System.Write.Atomic.swift
// Atomic file writing with crash-safety guarantees
//
// This module provides atomic file writes using the standard pattern:
//   1. Write to a temporary file in the same directory
//   2. Sync the file to disk (fsync)
//   3. Atomically rename temp → destination (rename is atomic on POSIX/NTFS)
//   4. Sync the directory to ensure the rename is persisted
//
// This guarantees that on any crash or power failure, you either have:
//   - The complete new file, or
//   - The complete old file (or no file if it didn't exist)
// You never get a partial/corrupted file.
//
// ## Security Considerations
//
// ### Symlink/Reparse-Point Handling
// This library does NOT provide hardened path resolution against symlink attacks.
// The O_NOFOLLOW flag (when used) only protects the final path component.
//
// **Threat model:**
// - Safe for: Writing to directories YOU control (application data, caches)
// - NOT safe for: Writing to attacker-controlled paths (e.g., /tmp with user input)
//
// Intermediate path components can still be symlinks, enabling TOCTOU attacks
// where an attacker replaces a directory with a symlink between path validation
// and file creation.
//
// For security-critical use cases in adversarial environments, consider:
// 1. Using openat() with O_NOFOLLOW at each path component
// 2. Validating the entire path is within expected bounds before writing
// 3. Using OS-provided secure temp directory APIs
// 4. Avoiding user-controlled path components entirely

import Binary_Primitives
public import Kernel

extension File.System.Write {
    /// Atomic file writing with crash-safety guarantees.
    public enum Atomic {}
}

// MARK: - Core API

extension File.System.Write.Atomic {
    /// Atomically writes bytes to a file path.
    ///
    /// This is the core primitive - all other write operations compose on top of this.
    ///
    /// ## Guarantees
    /// - Either the file exists with complete contents, or the original state is preserved
    /// - On success, data is synced to physical storage (survives power loss)
    /// - Safe to call concurrently for different paths
    ///
    /// ## Requirements
    /// - Parent directory must exist and be writable (unless `createIntermediates` is `true`)
    ///
    /// - Parameters:
    ///   - bytes: The data to write (borrowed, zero-copy)
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (strategy, durability, metadata)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write(
        _ bytes: borrowing Swift.Span<Byte>,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try ensureParent(for: path, createIntermediates: createIntermediates)
        try Self.write(bytes, to: path.kernelPath, options: options)
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic {
    /// Atomically writes a Binary.Serializable value to a file path.
    ///
    /// Uses `withSerializedBytes` for zero-copy access when the type supports it.
    ///
    /// - Parameters:
    ///   - value: The serializable value to write
    ///   - path: Destination file path
    ///   - options: Write options controlling how to write (strategy, durability, metadata)
    ///   - createIntermediates: If `true`, creates missing parent directories before writing
    /// - Throws: `File.System.Write.Atomic.Error` on failure
    public static func write<S: Binary.Serializable>(
        _ value: S,
        to path: borrowing File.Path,
        options: Options = Options(),
        createIntermediates: Bool = false
    ) throws(Error) {
        try S.withSerializedBytes(value) {
            (span: borrowing Swift.Span<Byte>) throws(Error) in
            try write(span, to: path, options: options, createIntermediates: createIntermediates)
        }
    }
}

// MARK: - Parent Directory

extension File.System.Write.Atomic {
    private static func ensureParent(
        for path: borrowing File.Path,
        createIntermediates: Bool
    ) throws(Error) {
        guard createIntermediates else { return }
        let parent = path.parentOrSelf
        do {
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
