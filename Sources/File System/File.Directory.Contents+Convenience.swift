//
//  File.Directory.Contents+Convenience.swift
//  swift-file-system
//
//  Convenience collectors for directory iteration.
//

import File_System_Core

extension File.Directory.Contents {
    /// Collects all file names in a directory.
    ///
    /// This is a convenience wrapper that collects all names into an array.
    /// For performance-critical iteration, use `makeIterator(at:)` directly.
    ///
    /// - Parameter directory: The directory to list.
    /// - Returns: An array of file names.
    /// - Throws: `Error` if the directory cannot be opened.
    public static func names(
        at directory: File.Directory
    ) throws(Self.Error) -> [File.Name] {
        let (iterator, handle) = try makeIterator(at: directory)
        defer { closeIterator(handle) }

        var names: [File.Name] = []
        var iter = iterator
        while let name = iter.next() {
            names.append(name)
        }

        // Check for errors that occurred during iteration
        if let error = iteratorError(for: iter, directory: directory) {
            throw error
        }

        return names
    }
}
