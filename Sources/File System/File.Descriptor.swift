//
//  File.Descriptor.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Descriptor {
    /// Duplicates this file descriptor.
    ///
    /// Creates a new file descriptor that refers to the same open file.
    /// Both descriptors can be used independently and must be closed separately.
    ///
    /// ## Example
    /// ```swift
    /// let original = try File.Descriptor.open(path, mode: .read)
    /// var duplicate = try original.duplicated()
    /// // Both can be used independently
    /// ```
    ///
    /// - Returns: A new file descriptor referring to the same file.
    /// - Throws: `File.Descriptor.Error.duplicateFailed` on failure.
    @inlinable
    public func duplicated() throws(File.Descriptor.Error) -> File.Descriptor {
        try File.Descriptor(duplicating: self)
    }
}

// MARK: - Error CustomStringConvertible

extension File.Descriptor.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "File already exists: \(path)"
        case .isDirectory(let path):
            return "Is a directory: \(path)"
        case .tooManyOpenFiles:
            return "Too many open files"
        case .invalidDescriptor:
            return "Invalid file descriptor"
        case .openFailed(let errno, let message):
            return "Open failed: \(message) (errno=\(errno))"
        case .closeFailed(let errno, let message):
            return "Close failed: \(message) (errno=\(errno))"
        case .duplicateFailed(let errno, let message):
            return "Duplicate failed: \(message) (errno=\(errno))"
        case .alreadyClosed:
            return "Descriptor already closed"
        }
    }
}
