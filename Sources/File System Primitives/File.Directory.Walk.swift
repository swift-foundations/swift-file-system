//
//  File.Directory.Walk.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    internal import WinSDK
#endif

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
        options: Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        var visited: Set<InodeKey> = []
        try Self._walk(
            at: File.Directory(path),
            options: options,
            depth: 0,
            entries: &entries,
            visited: &visited
        )
        return entries
    }
}

// MARK: - Variants

extension File.Directory.Walk {
    /// Recursively walks the directory tree and returns all entries.
    ///
    /// Explicit method alternative to `dir.walk()`.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func entries(
        options: Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
        try self(options: options)
    }

    /// Recursively walks the directory tree and returns all files.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all files found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func files(
        options: Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File] {
        try entries(options: options)
            .filter { $0.type == .file }
            .compactMap { $0.pathIfValid.map { File($0) } }
    }

    /// Recursively walks the directory tree and returns all subdirectories.
    ///
    /// - Parameter options: Walk options (maxDepth, followSymlinks, includeHidden).
    /// - Returns: An array of all directories found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    @inlinable
    public func directories(
        options: Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File.Directory] {
        try entries(options: options)
            .filter { $0.type == .directory }
            .compactMap { $0.pathIfValid.map { File.Directory($0) } }
    }
}

// MARK: - Cycle Detection

extension File.Directory.Walk {
    /// Key for tracking visited directories to detect cycles.
    ///
    /// Uses (device, inode) pair which uniquely identifies a file/directory
    /// across the filesystem.
    @usableFromInline
    internal struct InodeKey: Hashable {
        let device: UInt64
        let inode: UInt64
    }

    /// Gets the inode key for a path, following symlinks.
    ///
    /// Uses `stat` (not `lstat`) to get the target's identity when following symlinks.
    @usableFromInline
    internal static func getInodeKey(at path: File.Path) -> InodeKey? {
        guard let info = try? File.System.Stat.info(at: path) else { return nil }
        return InodeKey(device: info.deviceId, inode: info.inode)
    }
}

// MARK: - Implementation

extension File.Directory.Walk {
    @usableFromInline
    internal static func _walk(
        at directory: File.Directory,
        options: Options,
        depth: Int,
        entries: inout [File.Directory.Entry],
        visited: inout Set<InodeKey>
    ) throws(File.Directory.Walk.Error) {
        // Check depth limit
        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }

        // Cycle detection: mark this directory as visited when followSymlinks is enabled.
        // This provides deterministic termination when symlinks create cycles.
        if options.followSymlinks {
            if let key = getInodeKey(at: directory.path) {
                let (inserted, _) = visited.insert(key)
                if !inserted {
                    // Already visited - cycle detected, skip this directory
                    return
                }
            }
        }

        // List directory contents
        let contents: [File.Directory.Entry]
        do {
            contents = try File.Directory.Contents.list(at: directory)
        } catch let error {
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

        for entry in contents {
            // Filter hidden files using semantic predicate (no raw access)
            if !options.includeHidden && entry.name.isHiddenByDotPrefix {
                continue
            }

            // Try to get the path - if successful, entry is decodable
            if let entryPath = entry.pathIfValid {
                // Decodable - emit and recurse if directory
                entries.append(entry)

                if entry.type == .directory {
                    let subdir = File.Directory(entryPath)
                    try _walk(
                        at: subdir,
                        options: options,
                        depth: depth + 1,
                        entries: &entries,
                        visited: &visited
                    )
                } else if entry.type == .symbolicLink && options.followSymlinks {
                    // Check if symlink points to a directory (follows symlink via stat)
                    if let info = try? File.System.Stat.info(at: entryPath),
                        info.type == .directory
                    {
                        // Cycle detection for symlink targets is handled by the visited set
                        // because getInodeKey follows symlinks
                        let subdir = File.Directory(entryPath)
                        try _walk(
                            at: subdir,
                            options: options,
                            depth: depth + 1,
                            entries: &entries,
                            visited: &visited
                        )
                    }
                }
            } else {
                // Undecodable - invoke callback to decide
                let context = Undecodable.Context(
                    parent: entry.parent,
                    name: entry.name,
                    type: entry.type,
                    depth: depth
                )
                switch options.onUndecodable(context) {
                case .skip:
                    continue  // Do not emit, do not descend
                case .emit:
                    entries.append(entry)  // Emit entry, do not descend
                case .stopAndThrow:
                    throw .undecodableEntry(parent: entry.parent, name: entry.name)
                }
            }
        }
    }
}
