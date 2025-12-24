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
            guard stat(String(directory.path), &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = opendir(String(directory.path)) else {
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
            guard stat(String(directory.path), &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = Glibc.opendir(String(directory.path)) else {
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
            guard stat(String(directory.path), &statBuf) == 0 else {
                throw Self._mapErrno(errno, path: directory.path)
            }
            guard (statBuf.st_mode & S_IFMT) == S_IFDIR else {
                throw .notADirectory(directory.path)
            }

            guard let dir = Musl.opendir(String(directory.path)) else {
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

// MARK: - Windows Implementation

#elseif os(Windows)
    import WinSDK

    extension File.Directory.Contents {
        /// Iterator for directory names (Windows).
        ///
        /// Yields `File.Name` values one-by-one without constructing paths.
        /// Use this for performance-critical iteration where you only need names.
        public struct Iterator: IteratorProtocol {
            internal let _handle: HANDLE
            internal var _findData: WIN32_FIND_DATAW
            internal var _hasFirst: Bool
            internal var _finished: Bool = false

            internal init(handle: HANDLE, findData: WIN32_FIND_DATAW) {
                self._handle = handle
                self._findData = findData
                self._hasFirst = true
            }

            public mutating func next() -> File.Name? {
                guard !_finished else { return nil }

                // First call returns the entry from FindFirstFileW
                if _hasFirst {
                    _hasFirst = false
                    let name = File.Name(windowsDirectoryEntryName: _findData.cFileName)
                    if name.isDotOrDotDot {
                        return next()
                    }
                    return name
                }

                // Subsequent calls use FindNextFileW
                guard _ok(FindNextFileW(_handle, &_findData)) else {
                    _finished = true
                    return nil
                }

                let name = File.Name(windowsDirectoryEntryName: _findData.cFileName)
                if name.isDotOrDotDot {
                    return next()
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
            let path = directory.path
            let attrs = String(path).withCString(encodedAs: UTF16.self) { wpath in
                GetFileAttributesW(wpath)
            }

            guard attrs != INVALID_FILE_ATTRIBUTES else {
                throw .pathNotFound(path)
            }

            guard (attrs & _mask(FILE_ATTRIBUTE_DIRECTORY)) != 0 else {
                throw .notADirectory(path)
            }

            var findData = WIN32_FIND_DATAW()
            let searchPath = String(path) + "\\*"

            let handle = searchPath.withCString(encodedAs: UTF16.self) { wpath in
                FindFirstFileW(wpath, &findData)
            }

            guard let validHandle = handle, validHandle != INVALID_HANDLE_VALUE else {
                let error = GetLastError()
                switch error {
                case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                    throw .pathNotFound(path)
                case _dword(ERROR_ACCESS_DENIED):
                    throw .permissionDenied(path)
                default:
                    throw .readFailed(errno: Int32(error), message: "Windows error \(error)")
                }
            }

            return (Iterator(handle: validHandle, findData: findData), OpaquePointer(validHandle))
        }

        /// Closes an iterator handle.
        ///
        /// Must be called after iteration is complete to release system resources.
        ///
        /// - Parameter handle: The opaque handle returned by `makeIterator(at:)`.
        public static func closeIterator(_ handle: OpaquePointer) {
            FindClose(HANDLE(handle))
        }

        /// Checks if there was an error during iteration.
        ///
        /// Call this after the iterator returns `nil` to check if iteration
        /// ended due to an error or end-of-stream.
        ///
        /// - Returns: An error if the last error was not `ERROR_NO_MORE_FILES`, `nil` otherwise.
        public static func iteratorError(for directory: File.Directory) -> Error? {
            let lastError = GetLastError()
            if lastError != _dword(ERROR_NO_MORE_FILES) && lastError != 0 {
                switch lastError {
                case _dword(ERROR_FILE_NOT_FOUND), _dword(ERROR_PATH_NOT_FOUND):
                    return .pathNotFound(directory.path)
                case _dword(ERROR_ACCESS_DENIED):
                    return .permissionDenied(directory.path)
                default:
                    return .readFailed(errno: Int32(lastError), message: "Windows error \(lastError)")
                }
            }
            return nil
        }
    }
#endif
