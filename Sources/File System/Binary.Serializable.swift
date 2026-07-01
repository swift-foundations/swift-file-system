//
//  Binary.Serializable.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Binary_Primitives
public import Kernel

extension Binary.Serializable {
    /// Writes this serializable value atomically to a file.
    ///
    /// Uses the atomic write-sync-rename pattern for crash safety.
    ///
    /// - Parameters:
    ///   - path: Destination file path.
    ///   - options: Write options (strategy, durability, metadata preservation).
    ///   - createIntermediates: If `true`, creates missing parent directories before writing.
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        to path: File.Path,
        options: File.System.Write.Atomic.Options = .init(),
        createIntermediates: Bool = false
    ) throws(File.System.Write.Atomic.Error) {
        try File.System.Write.Atomic.write(self, to: path, options: options, createIntermediates: createIntermediates)
    }

    /// Writes this serializable value atomically to a file.
    ///
    /// Uses the atomic write-sync-rename pattern for crash safety.
    ///
    /// - Parameters:
    ///   - file: Destination file.
    ///   - options: Write options (strategy, durability, metadata preservation).
    ///   - createIntermediates: If `true`, creates missing parent directories before writing.
    /// - Throws: `File.System.Write.Atomic.Error` on failure.
    public func write(
        to file: File,
        options: File.System.Write.Atomic.Options = .init(),
        createIntermediates: Bool = false
    ) throws(File.System.Write.Atomic.Error) {
        try write(to: file.path, options: options, createIntermediates: createIntermediates)
    }
}
