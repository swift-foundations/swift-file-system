//
//  File.Directory.Contents.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

#if !os(Windows)
extension File.Directory.Contents {
    /// Iterator for directory names (POSIX).
    ///
    /// Yields `File.Name` values one-by-one without constructing paths.
    /// Use this for performance-critical iteration where you only need names.
    public struct Iterator: IteratorProtocol {
        internal let _dir: UnsafeMutablePointer<DIR>
        internal var _finished: Bool = false

        internal init(dir: UnsafeMutablePointer<DIR>) {
            self._dir = dir
        }

        public mutating func next() -> File.Name? {
            guard !_finished else { return nil }

            // Set errno before readdir to distinguish end-of-stream from error
            errno = 0
            guard let entry = readdir(_dir) else {
                _finished = true
                // errno != 0 means error, but IteratorProtocol.next() can't throw
                // Caller should use iteratorError(for:) after iteration if needed
                return nil
            }

            let name = File.Name(posixDirectoryEntryName: entry.pointee.d_name)
            if name.isDotOrDotDot {
                return next()  // Skip . and ..
            }
            return name
        }
    }

    /// Creates an iterator for directory names.
    ///
    /// The caller is responsible for closing the handle via `closeIterator(_:)`.
    ///
    /// - Parameter path: The path to the directory.
    /// - Returns: A tuple of the iterator and an opaque handle for cleanup.
    /// - Throws: `Error` if the directory cannot be opened.
    public static func makeIterator(
        at path: File.Path
    ) throws(Error) -> (iterator: Iterator, handle: OpaquePointer) {
        var statBuf = stat()
        guard stat(path.string, &statBuf) == 0 else {
            throw Self._mapErrno(errno, path: path)
        }
        guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
            throw .notADirectory(path)
        }

        guard let dir = opendir(path.string) else {
            throw Self._mapErrno(errno, path: path)
        }

        return (Iterator(dir: dir), OpaquePointer(dir))
    }

    /// Closes an iterator handle.
    ///
    /// Must be called after iteration is complete to release system resources.
    ///
    /// - Parameter handle: The opaque handle returned by `makeIterator(at:)`.
    public static func closeIterator(_ handle: OpaquePointer) {
        closedir(UnsafeMutablePointer(handle))
    }

    /// Checks if there was an error during iteration.
    ///
    /// Call this after the iterator returns `nil` to check if iteration
    /// ended due to an error or end-of-stream.
    ///
    /// - Returns: An error if `errno` was set, `nil` otherwise.
    public static func iteratorError(for path: File.Path) -> Error? {
        if errno != 0 {
            return Self._mapErrno(errno, path: path)
        }
        return nil
    }
}
#endif
