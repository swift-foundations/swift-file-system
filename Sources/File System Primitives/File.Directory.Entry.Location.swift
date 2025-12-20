//
//  File.Directory.Entry.Location.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Entry {
    /// The location of a directory entry.
    ///
    /// Both cases store parent explicitly - no computed fallback needed.
    /// This ensures the parent is always available regardless of whether
    /// the name could be decoded to a String.
    ///
    /// ## Cases
    /// - `.absolute(parent:path:)`: Name was successfully decoded to String.
    ///   Both parent and full path are stored explicitly.
    /// - `.relative(parent:)`: Name could not be decoded (invalid UTF-8/UTF-16
    ///   or contains invalid path characters). Only parent is available;
    ///   use `Entry.name` for raw filesystem operations.
    public enum Location: Sendable, Equatable {
        /// Absolute path - name was successfully decoded to String.
        ///
        /// Parent is stored explicitly (no fallback computation).
        case absolute(parent: File.Path, path: File.Path)

        /// Relative reference - name could not be decoded.
        ///
        /// Use the parent path and raw `Entry.name` for operations.
        case relative(parent: File.Path)
    }
}

// MARK: - Convenience Accessors

extension File.Directory.Entry.Location {
    /// The parent directory path. Always available.
    @inlinable
    public var parent: File.Path {
        switch self {
        case .absolute(let parent, _): return parent
        case .relative(let parent): return parent
        }
    }

    /// The absolute path, if the name was decodable.
    ///
    /// Returns `nil` for `.relative` locations where the name could not
    /// be decoded to a valid String.
    @inlinable
    public var path: File.Path? {
        switch self {
        case .absolute(_, let path): return path
        case .relative: return nil
        }
    }
}
