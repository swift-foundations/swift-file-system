//
//  File.Directory.Contents+Convenience.swift
//  swift-file-system
//
//  Convenience collectors for directory iteration.
//

import File_System_Primitives

extension File.Directory.Contents {
    /// Collects all file names in a directory.
    ///
    /// This is a convenience wrapper that collects all names into an array.
    /// For performance-critical iteration, use `makeIterator(at:)` directly.
    ///
    /// - Parameter path: The path to the directory.
    /// - Returns: An array of file names.
    /// - Throws: `Error` if the directory cannot be opened.
    public static func names(at path: File.Path) throws(Error) -> [File.Name] {
        #if os(Windows)
            // Windows uses the existing _listWindows and extracts names
            return try _listWindows(at: path).map(\.name)
        #else
            let (iterator, handle) = try makeIterator(at: path)
            defer { closeIterator(handle) }

            var names: [File.Name] = []
            var iter = iterator
            while let name = iter.next() {
                names.append(name)
            }

            // Check for errors that occurred during iteration
            if let error = iteratorError(for: path) {
                throw error
            }

            return names
        #endif
    }
}
