//
//  File.Name+Convenience.swift
//  swift-file-system
//
//  Convenience copying initializers for File.Name bytes.
//

import File_System_Core

extension [UInt8] {
    // substrate: codec (POSIX UTF-8 byte materialization) — deprecated public surface; `withCodeUnits` is the canonical zero-copy path
    /// Creates a byte array by copying the file name's raw UTF-8 bytes.
    ///
    /// For zero-copy access, use `name.withCodeUnits { span in ... }` instead.
    ///
    /// - Parameter fileName: The file name to copy bytes from.
    /// - Returns: `nil` if the file name uses Windows encoding.
    @available(*, deprecated, message: "Use `name.withCodeUnits { span in Array(span) }` (POSIX) for cross-platform zero-copy access; this POSIX-only allocating convenience is superseded.")
    @inlinable
    public init?(copying fileName: File.Name) {
        #if os(Windows)
            return nil
        #else
            self = fileName.rawBytes
        #endif
    }
}

extension [UInt16] {
    // substrate: codec (Windows UTF-16 code-unit materialization) — deprecated public surface; `withCodeUnits` is the canonical zero-copy path
    /// Creates a code unit array by copying the file name's raw UTF-16 code units.
    ///
    /// For zero-copy access, use `name.withCodeUnits { span in ... }` instead.
    ///
    /// - Parameter fileName: The file name to copy code units from.
    /// - Returns: `nil` if the file name uses POSIX encoding.
    @available(*, deprecated, message: "Use `name.withCodeUnits { span in Array(span) }` (Windows) for cross-platform zero-copy access; this Windows-only allocating convenience is superseded.")
    @inlinable
    public init?(copying fileName: File.Name) {
        #if os(Windows)
            self = fileName.rawBytes
        #else
            return nil
        #endif
    }
}
