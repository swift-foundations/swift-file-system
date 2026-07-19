//
//  File.Directory.Walk.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Either_Primitives
import Kernel

extension File.Directory {
    /// Namespace for recursive directory traversal operations.
    ///
    /// Access via the `walk` property on a `File.Directory` instance.
    /// This namespace is callable for the common case:
    /// ```swift
    /// let dir: File.Directory = "/tmp/mydir"
    ///
    /// // Common case - callable (all entries recursively)
    /// for entry in try dir.walk() { ... }
    ///
    /// // Walk files only
    /// for file in try dir.walk.files() { ... }
    ///
    /// // Walk directories only
    /// for subdir in try dir.walk.directories() { ... }
    /// ```
    public struct Walk: Sendable {
        /// The directory path to walk.
        public let path: File.Path

        /// Creates a Walk instance.
        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

// MARK: - Instance Property

extension File.Directory {
    /// Access to recursive directory traversal operations.
    ///
    /// Use this property to walk the directory tree:
    /// ```swift
    /// for entry in try dir.walk.entries() { ... }
    /// for file in try dir.walk.files() { ... }
    /// for subdir in try dir.walk.directories() { ... }
    /// ```
    public var walk: Walk {
        Walk(path)
    }
}

// MARK: - callAsFunction (Primary Action)

extension File.Directory.Walk {
    /// Recursively walks the directory tree and returns all entries.
    ///
    /// This is the primary action, accessible via `dir.walk()`.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    ///
    /// - Note: When `followSymlinks` is enabled, cycle detection is performed using
    ///   inode-based tracking to prevent infinite loops from symlink cycles.
    @inlinable
    public func callAsFunction(
        options: borrowing Options = Options()
    ) throws(Self.Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        try iterate(options: options) { entry in
            entries.append(entry)
            return .continue
        }
        return entries
    }
}

// MARK: - Callback-Based API (Zero-Allocation)

extension File.Directory.Walk {
    /// Recursively walks the directory tree, calling a closure for each entry.
    ///
    /// This is the canonical walk API. It avoids allocating an array by yielding
    /// each entry to the callback. Use `Control.break` for early exit.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Process entries without allocation
    /// try dir.walk.iterate { entry in
    ///     print(entry.name)
    ///     return .continue
    /// }
    ///
    /// // Find first match
    /// var found: File.Directory.Entry?
    /// try dir.walk.iterate { entry in
    ///     if entry.name.string == "target.txt" {
    ///         found = entry
    ///         return .break
    ///     }
    ///     return .continue
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - options: Walk options (maxDepth, followSymlinks, includeHidden).
    ///   - body: A closure called for each entry. Return `.continue` to keep walking,
    ///           or `.break` to stop early.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func iterate(
        options: borrowing Options = Options(),
        body: (File.Directory.Entry) -> File.Directory.Contents.Control
    ) throws(Self.Error) {
        var visited: Set<InodeKey> = []
        var stopped = false
        try Self.walkCallback(
            at: File.Directory(path),
            options: options,
            depth: 0,
            visited: &visited,
            stopped: &stopped,
            body: body
        )
    }

    /// Recursively walks the directory tree with a throwing closure.
    ///
    /// - Parameters:
    ///   - options: Walk options.
    ///   - body: A throwing closure called for each entry.
    /// - Throws: `Either<Walk.Error, E>` — `.left` for traversal failures,
    ///   `.right` if the closure throws.
    public func iterate<E: Swift.Error>(
        options: borrowing Options = Options(),
        body: (File.Directory.Entry) throws(E) -> File.Directory.Contents.Control
    ) throws(Either<File.Directory.Walk.Error, E>) {
        var bodyError: E?
        do throws(Self.Error) {
            try iterate(options: options) { entry in
                do throws(E) {
                    return try body(entry)
                } catch {
                    bodyError = error
                    return .break
                }
            }
        } catch {
            throw .left(error)
        }
        if let error = bodyError {
            throw .right(error)
        }
    }

    /// Recursively walks files only, calling a closure for each file.
    ///
    /// - Parameters:
    ///   - options: Walk options.
    ///   - body: A closure called for each file.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func files(
        options: borrowing Options = Options(),
        body: (File) -> File.Directory.Contents.Control
    ) throws(Self.Error) {
        try iterate(options: options) { entry in
            guard entry.type == .file, let path = entry.pathIfValid else {
                return .continue
            }
            return body(File(path))
        }
    }

    /// Recursively walks directories only, calling a closure for each directory.
    ///
    /// - Parameters:
    ///   - options: Walk options.
    ///   - body: A closure called for each directory.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func directories(
        options: borrowing Options = Options(),
        body: (File.Directory) -> File.Directory.Contents.Control
    ) throws(Self.Error) {
        try iterate(options: options) { entry in
            guard entry.type == .directory, let path = entry.pathIfValid else {
                return .continue
            }
            return body(File.Directory(path))
        }
    }
}

// MARK: - Callback Implementation

extension File.Directory.Walk {
    @usableFromInline
    internal static func walkCallback(
        at directory: File.Directory,
        options: Options,
        depth: Int,
        visited: inout Set<InodeKey>,
        stopped: inout Bool,
        body: (File.Directory.Entry) -> File.Directory.Contents.Control
    ) throws(Self.Error) {
        // A nested level already signaled early exit (`.break`) — do not
        // descend into further siblings or subdirectories at this level.
        if stopped {
            return
        }

        // Check depth limit
        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }

        // Cycle detection
        if options.followSymlinks {
            if let key = getInodeKey(at: directory.path) {
                let (inserted, _) = visited.insert(key)
                if !inserted {
                    return  // Cycle detected
                }
            }
        }

        // Iterate directory contents
        var walkError: File.Directory.Walk.Error?

        do throws(File.Directory.Contents.Error) {
            try File.Directory.Contents.iterate(at: directory) { entry in
                // Filter hidden files
                if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                    return .continue
                }

                if let entryPath = entry.pathIfValid {
                    // Yield to callback
                    switch body(entry) {
                    case .continue:
                        break

                    case .break:
                        stopped = true
                        return .break
                    }

                    // Recurse into directories
                    if entry.type == .directory {
                        let subdir = File.Directory(entryPath)
                        do throws(Self.Error) {
                            try walkCallback(
                                at: subdir,
                                options: options,
                                depth: depth + 1,
                                visited: &visited,
                                stopped: &stopped,
                                body: body
                            )
                        } catch {
                            walkError = error
                            return .break
                        }
                        if stopped {
                            return .break
                        }
                    } else if entry.type == .symbolicLink && options.followSymlinks {
                        let info: File.System.Metadata.Info?
                        do throws(Kernel.File.Stats.Error) {
                            info = try File.System.Stat.info(at: entryPath)
                        } catch {
                            info = nil
                        }
                        if let info,
                            info.type == .directory
                        {
                            let subdir = File.Directory(entryPath)
                            do throws(Self.Error) {
                                try walkCallback(
                                    at: subdir,
                                    options: options,
                                    depth: depth + 1,
                                    visited: &visited,
                                    stopped: &stopped,
                                    body: body
                                )
                            } catch {
                                walkError = error
                                return .break
                            }
                            if stopped {
                                return .break
                            }
                        }
                    }
                } else {
                    // Undecodable entry
                    let context = Undecodable.Context(
                        parent: entry.parent,
                        name: entry.name,
                        type: entry.type,
                        depth: depth
                    )
                    switch options.onUndecodable(context) {
                    case .skip:
                        break

                    case .emit:
                        switch body(entry) {
                        case .continue:
                            break

                        case .break:
                            stopped = true
                            return .break
                        }

                    case .stopAndThrow:
                        walkError = .undecodableEntry(parent: entry.parent, name: entry.name)
                        return .break
                    }
                }

                return .continue
            }
        } catch {
            switch error {
            case .pathNotFound(let p):
                throw .pathNotFound(p)

            case .permissionDenied(let p):
                throw .permissionDenied(p)

            case .notADirectory(let p):
                throw .notADirectory(p)

            case .readFailed(let errno, let message):
                throw .walkFailed(errno: errno, message: message)
            }
        }

        if let error = walkError {
            throw error
        }
    }

}

// MARK: - Cycle Detection

extension File.Directory.Walk {
    /// Gets the inode key for a path, following symlinks.
    ///
    /// Uses `stat` (not `lstat`) to get the target's identity when following symlinks.
    @usableFromInline
    internal static func getInodeKey(at path: File.Path) -> InodeKey? {
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: path)
        } catch {
            return nil
        }
        return InodeKey(device: info.device, inode: info.inode)
    }
}
