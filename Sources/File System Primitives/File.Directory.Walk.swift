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
    public import WinSDK
#endif

extension File.Directory {
    /// Recursive directory traversal.
    public enum Walk {}
}

// MARK: - Core API

extension File.Directory.Walk {
    /// Recursively walks a directory and returns all entries.
    ///
    /// - Parameters:
    ///   - directory: The root directory to walk.
    ///   - options: Walk options.
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    ///
    /// - Note: When `followSymlinks` is enabled, cycle detection is performed using
    ///   inode-based tracking to prevent infinite loops from symlink cycles. This
    ///   behavior is consistent across all platforms.
    public static func walk(
        at directory: File.Directory,
        options: Options = Options()
    ) throws(File.Directory.Walk.Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        var visited: Set<InodeKey> = []
        try _walk(
            at: directory,
            options: options,
            depth: 0,
            entries: &entries,
            visited: &visited
        )
        return entries
    }
}

// MARK: - Cycle Detection

extension File.Directory.Walk {
    /// Key for tracking visited directories to detect cycles.
    ///
    /// Uses (device, inode) pair which uniquely identifies a file/directory
    /// across the filesystem.
    private struct InodeKey: Hashable {
        let device: UInt64
        let inode: UInt64
    }

    /// Gets the inode key for a path, following symlinks.
    ///
    /// Uses `stat` (not `lstat`) to get the target's identity when following symlinks.
    private static func getInodeKey(at path: File.Path) -> InodeKey? {
        guard let info = try? File.System.Stat.info(at: path) else { return nil }
        return InodeKey(device: info.deviceId, inode: info.inode)
    }
}

// MARK: - Implementation

extension File.Directory.Walk {
    private static func _walk(
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
