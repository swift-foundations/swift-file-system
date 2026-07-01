//
//  File.Directory.Iterator.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.Directory {
    /// A streaming directory iterator that yields entries one at a time.
    ///
    /// This is a ~Copyable type that owns the underlying directory handle
    /// and closes it when done.
    ///
    /// ## Thread Safety
    /// `Iterator` is **NOT** `Sendable`. It owns mutable state (the directory handle)
    /// and is not safe for concurrent use. For cross-task usage, wrap in an actor
    /// or use the async layer.
    public struct Iterator: ~Copyable /* NOT Sendable - owns mutable directory handle */ {
        private var _stream: Kernel.Directory.Stream?
        private let _basePath: File.Path

        /// Creates an iterator wrapping a kernel directory stream.
        private init(stream: Kernel.Directory.Stream, basePath: File.Path) {
            self._stream = stream
            self._basePath = basePath
        }

        deinit {
            _stream?.close()
        }
    }
}

// MARK: - Error (Union of Kernel Errors)

extension File.Directory.Iterator {
    /// Errors that can occur during iteration.
    ///
    /// This wraps the kernel directory error directly.
    /// Use semantic accessors like `isNotFound` or `isPermissionDenied` for common checks,
    /// or match on the case for full error details.
    public enum Error: Swift.Error, Sendable {
        /// Error from directory operation.
        case directory(Kernel.Directory.Error)
    }
}

// MARK: - Semantic Accessors

extension File.Directory.Iterator.Error {
    /// Returns `true` if the path was not found.
    public var isNotFound: Bool {
        if case .directory(let e) = self {
            return e == .notFound
        }
        return false
    }

    /// Returns `true` if permission was denied.
    public var isPermissionDenied: Bool {
        if case .directory(let e) = self {
            return e == .permission
        }
        return false
    }

    /// Returns `true` if the path is not a directory.
    public var isNotADirectory: Bool {
        if case .directory(let e) = self {
            return e == .notDirectory
        }
        return false
    }

    /// Returns `true` if there are too many open files.
    public var isTooManyOpenFiles: Bool {
        if case .directory(let e) = self {
            return e == .tooManyOpenFiles
        }
        return false
    }
}

// MARK: - Core API

extension File.Directory.Iterator {
    /// Opens a directory for iteration.
    ///
    /// - Parameter directory: The directory to iterate.
    /// - Returns: An iterator for the directory.
    /// - Throws: `File.Directory.Iterator.Error` on failure.
    public static func open(
        at directory: File.Directory
    ) throws(File.Directory.Iterator.Error) -> File.Directory.Iterator {
        let stream: Kernel.Directory.Stream
        do {
            stream = try Kernel.Directory.open(at: directory.path.kernelPath)
        } catch {
            throw .directory(error)
        }

        return File.Directory.Iterator(stream: stream, basePath: directory.path)
    }

    /// Returns the next entry in the directory, or nil if done.
    ///
    /// - Returns: The next directory entry, or nil if iteration is complete.
    /// - Throws: `File.Directory.Iterator.Error` on failure.
    public mutating func next() throws(File.Directory.Iterator.Error) -> File.Directory.Entry? {
        guard let stream = _stream else {
            return nil
        }

        while true {
            let kernelEntry: Kernel.Directory.Entry?
            do {
                kernelEntry = try stream.next()
            } catch {
                throw .directory(error)
            }

            guard let entry = kernelEntry else {
                return nil  // End of directory
            }

            // Create File.Name from Kernel.Directory.Entry
            let name = File.Name(from: entry)

            // Skip . and .. using raw byte comparison
            if name.isDotOrDotDot {
                continue
            }

            // Map Kernel.File.Stats.Kind to File.Directory.Entry.Kind
            let entryType: File.Directory.Entry.Kind
            if let type = entry.type {
                switch type {
                case .regular:
                    entryType = .file
                case .directory:
                    entryType = .directory
                case .link(.symbolic):
                    entryType = .symbolicLink
                default:
                    entryType = .other
                }
            } else {
                // Type unknown - fall back to stat
                entryType = statForType(name: name)
            }

            return File.Directory.Entry(name: name, parent: _basePath, type: entryType)
        }
    }

    /// Closes the iterator and releases resources.
    public consuming func close() {
        _stream?.close()
        _stream = nil
    }

    /// Stat fallback for when d_type is unknown.
    private func statForType(name: File.Name) -> File.Directory.Entry.Kind {
        guard
            let entryPath = File.Directory.Entry(
                name: name,
                parent: _basePath,
                type: .other
            ).pathIfValid
        else {
            return .other
        }

        do {
            let stats = try Kernel.File.Stats.lget(path: entryPath.kernelPath)
            switch stats.type {
            case .regular:
                return .file
            case .directory:
                return .directory
            case .link(.symbolic), .link:
                return .symbolicLink
            default:
                return .other
            }
        } catch {
            return .other
        }
    }
}

// MARK: - CustomStringConvertible for Error

extension File.Directory.Iterator.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .directory(let error):
            return "Directory iteration failed: \(error)"
        }
    }
}
