//
//  File.Directory.Contents.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Kernel

extension File.Directory.Contents {
    /// Iterator for directory names.
    ///
    /// Yields `File.Name` values one-by-one without constructing paths.
    /// Use this for performance-critical iteration where you only need names.
    public struct Iterator: IteratorProtocol {
        internal let _stream: Kernel.Directory.Stream
        internal var _finished: Bool = false
        internal var _lastError: Kernel.Directory.Error? = nil

        internal init(stream: Kernel.Directory.Stream) {
            self._stream = stream
        }

        public mutating func next() -> File.Name? {
            guard !_finished else { return nil }

            do {
                guard let entry = try _stream.next() else {
                    _finished = true
                    return nil
                }

                // Skip . and ..
                if entry.isDotOrDotDot {
                    return next()
                }

                return File.Name(from: entry)
            } catch {
                _finished = true
                _lastError = error
                return nil
            }
        }
    }

    /// Creates an iterator for directory names.
    ///
    /// The caller is responsible for closing the handle via `closeIterator(_:)`.
    ///
    /// - Parameter directory: The directory to iterate.
    /// - Returns: A tuple of the iterator and a handle for cleanup.
    /// - Throws: `Error` if the directory cannot be opened.
    public static func makeIterator(
        at directory: File.Directory
    ) throws(File.Directory.Contents.Error) -> (iterator: Iterator, handle: IteratorHandle) {
        let stream: Kernel.Directory.Stream
        do throws(Kernel.Directory.Error) {
            stream = try Kernel.Directory.open(at: directory.path.kernelPath)
        } catch {
            throw mapKernelError(error, path: directory.path)
        }

        let handle = IteratorHandle(stream: stream)
        return (Iterator(stream: stream), handle)
    }

    /// Closes an iterator handle.
    ///
    /// Must be called after iteration is complete to release system resources.
    ///
    /// - Parameter handle: The handle returned by `makeIterator(at:)`.
    public static func closeIterator(_ handle: IteratorHandle) {
        handle.stream.close()
    }

    /// Checks if there was an error during iteration.
    ///
    /// Call this after the iterator returns `nil` to check if iteration
    /// ended due to an error or end-of-stream.
    ///
    /// - Parameter iterator: The iterator to check.
    /// - Parameter directory: The directory being iterated (for error context).
    /// - Returns: An error if one occurred, `nil` otherwise.
    public static func iteratorError(
        for iterator: Iterator,
        directory: File.Directory
    ) -> Error? {
        guard let kernelError = iterator._lastError else {
            return nil
        }
        return mapKernelReadError(kernelError, path: directory.path)
    }
}

// MARK: - Error Mapping

extension File.Directory.Contents {
    /// Maps Kernel.Directory.Error to File.Directory.Contents.Error for read operations.
    private static func mapKernelReadError(
        _ error: Kernel.Directory.Error,
        path: File.Path
    ) -> Error {
        switch error {
        case .io:
            return .readFailed(errno: 0, message: "I/O error during iteration")
        case .platform(let kernelError):
            let errno = kernelError.code.posix ?? Int32(kernelError.code.win32 ?? 0)
            return .readFailed(errno: errno, message: "\(kernelError)")
        default:
            return .readFailed(errno: 0, message: "\(error)")
        }
    }
}
