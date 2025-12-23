//
//  File.Directory.Contents.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

// MARK: - Darwin Implementation

#if canImport(Darwin)
    import Darwin

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
            at directory: File.Directory
        ) throws(File.Directory.Contents.Error) -> (iterator: Iterator, handle: OpaquePointer) {
            var statBuf = stat()
            guard stat(directory.path.string, &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = opendir(directory.path.string) else {
                throw Self._mapErrno(errno, path: directory.path)
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
        public static func iteratorError(for directory: File.Directory) -> Error? {
            if errno != 0 {
                return Self._mapErrno(errno, path: directory.path)
            }
            return nil
        }
    }

// MARK: - Glibc Implementation

#elseif canImport(Glibc)
    import Glibc
    import CFileSystemShims

    extension File.Directory.Contents {
        /// Iterator for directory names (POSIX).
        ///
        /// Yields `File.Name` values one-by-one without constructing paths.
        /// Use this for performance-critical iteration where you only need names.
        public struct Iterator: IteratorProtocol {
            // Use OpaquePointer on Linux (DIR type not exported in Swift's Glibc overlay)
            internal let _dir: OpaquePointer
            internal var _finished: Bool = false

            internal init(dir: OpaquePointer) {
                self._dir = dir
            }

            public mutating func next() -> File.Name? {
                guard !_finished else { return nil }

                // Set errno before readdir to distinguish end-of-stream from error
                errno = 0
                guard let entry = Glibc.readdir(_dir) else {
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
        /// - Parameter directory: The directory to iterate.
        /// - Returns: A tuple of the iterator and an opaque handle for cleanup.
        /// - Throws: `Error` if the directory cannot be opened.
        public static func makeIterator(
            at directory: File.Directory
        ) throws(File.Directory.Contents.Error) -> (iterator: Iterator, handle: OpaquePointer) {
            var statBuf = stat()
            guard stat(directory.path.string, &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = Glibc.opendir(directory.path.string) else {
                throw Self._mapErrno(errno, path: directory.path)
            }

            return (Iterator(dir: dir), dir)
        }

        /// Closes an iterator handle.
        ///
        /// Must be called after iteration is complete to release system resources.
        ///
        /// - Parameter handle: The opaque handle returned by `makeIterator(at:)`.
        public static func closeIterator(_ handle: OpaquePointer) {
            Glibc.closedir(handle)
        }

        /// Checks if there was an error during iteration.
        ///
        /// Call this after the iterator returns `nil` to check if iteration
        /// ended due to an error or end-of-stream.
        ///
        /// - Returns: An error if `errno` was set, `nil` otherwise.
        public static func iteratorError(for directory: File.Directory) -> Error? {
            if errno != 0 {
                return Self._mapErrno(errno, path: directory.path)
            }
            return nil
        }
    }

// MARK: - Musl Implementation

#elseif canImport(Musl)
    import Musl
    import CFileSystemShims

    extension File.Directory.Contents {
        /// Iterator for directory names (POSIX).
        ///
        /// Yields `File.Name` values one-by-one without constructing paths.
        /// Use this for performance-critical iteration where you only need names.
        public struct Iterator: IteratorProtocol {
            // Use OpaquePointer on Musl (same as Glibc)
            internal let _dir: OpaquePointer
            internal var _finished: Bool = false

            internal init(dir: OpaquePointer) {
                self._dir = dir
            }

            public mutating func next() -> File.Name? {
                guard !_finished else { return nil }

                // Set errno before readdir to distinguish end-of-stream from error
                errno = 0
                guard let entry = Musl.readdir(_dir) else {
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
        /// - Parameter directory: The directory to iterate.
        /// - Returns: A tuple of the iterator and an opaque handle for cleanup.
        /// - Throws: `Error` if the directory cannot be opened.
        public static func makeIterator(
            at directory: File.Directory
        ) throws(File.Directory.Contents.Error) -> (iterator: Iterator, handle: OpaquePointer) {
            var statBuf = stat()
            guard stat(directory.path.string, &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = Musl.opendir(directory.path.string) else {
                throw Self._mapErrno(errno, path: directory.path)
            }

            return (Iterator(dir: dir), dir)
        }

        /// Closes an iterator handle.
        ///
        /// Must be called after iteration is complete to release system resources.
        ///
        /// - Parameter handle: The opaque handle returned by `makeIterator(at:)`.
        public static func closeIterator(_ handle: OpaquePointer) {
            Musl.closedir(handle)
        }

        /// Checks if there was an error during iteration.
        ///
        /// Call this after the iterator returns `nil` to check if iteration
        /// ended due to an error or end-of-stream.
        ///
        /// - Returns: An error if `errno` was set, `nil` otherwise.
        public static func iteratorError(for directory: File.Directory) -> Error? {
            if errno != 0 {
                return Self._mapErrno(errno, path: directory.path)
            }
            return nil
        }
    }
#endif
