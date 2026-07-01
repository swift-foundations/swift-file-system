//
//  File.Handle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

public import Kernel

// MARK: - Seek Conveniences

extension File.Handle {
    /// Returns the current position in the file.
    ///
    /// Equivalent to `seek(to: 0, from: .current)`.
    ///
    /// - Returns: The current file position.
    /// - Throws: `Kernel.File.Seek.Error` on failure.
    @inlinable
    public mutating func position() throws(Kernel.File.Seek.Error) -> Int64 {
        try seek(to: 0, from: .current)
    }

    /// Seeks to the beginning of the file.
    ///
    /// Equivalent to `seek(to: 0, from: .start)`.
    ///
    /// ## Example
    /// ```swift
    /// try handle.rewind()
    /// let data = try handle.read(count: 100)  // Read from start
    /// ```
    ///
    /// - Returns: The new position (always 0).
    /// - Throws: `Kernel.File.Seek.Error` on failure.
    @discardableResult
    @inlinable
    public mutating func rewind() throws(Kernel.File.Seek.Error) -> Int64 {
        try seek(to: 0, from: .start)
    }

}
