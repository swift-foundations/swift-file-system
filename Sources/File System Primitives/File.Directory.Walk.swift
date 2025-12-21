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

// MARK: - Options

extension File.Directory.Walk {
    /// Options for directory traversal.
    public struct Options: Sendable {
        /// Maximum depth to traverse (nil for unlimited).
        public var maxDepth: Int?

        /// Whether to follow symbolic links.
        public var followSymlinks: Bool

        /// Whether to include hidden files.
        public var includeHidden: Bool

        /// Callback invoked when an entry with an undecodable name is encountered.
        ///
        /// Default: `.skip` (do not emit, do not descend).
        public var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy

        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true,
            onUndecodable: @escaping @Sendable (Undecodable.Context) -> Undecodable.Policy = { _ in .skip }
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
            self.onUndecodable = onUndecodable
        }
    }
}

// MARK: - Error

extension File.Directory.Walk {
    /// Errors that can occur during directory walk operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: String)
        case undecodableEntry(parent: File.Path, name: File.Name)
    }
}

// MARK: - Core API

extension File.Directory.Walk {
    /// Recursively walks a directory and returns all entries.
    ///
    /// - Parameters:
    ///   - path: The root directory to walk.
    ///   - options: Walk options.
    /// - Returns: An array of all entries found.
    /// - Throws: `File.Directory.Walk.Error` on failure.
    public static func walk(
        at path: File.Path,
        options: Options = Options()
    ) throws(Error) -> [File.Directory.Entry] {
        var entries: [File.Directory.Entry] = []
        try _walk(at: path, options: options, depth: 0, entries: &entries)
        return entries
    }

}

// MARK: - Implementation

extension File.Directory.Walk {
    private static func _walk(
        at path: File.Path,
        options: Options,
        depth: Int,
        entries: inout [File.Directory.Entry]
    ) throws(Error) {
        // Check depth limit
        if let maxDepth = options.maxDepth, depth > maxDepth {
            return
        }

        // List directory contents
        let contents: [File.Directory.Entry]
        do {
            contents = try File.Directory.Contents.list(at: path)
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
                    try _walk(at: entryPath, options: options, depth: depth + 1, entries: &entries)
                } else if entry.type == .symbolicLink && options.followSymlinks {
                    // Check if symlink points to a directory (follows symlink via stat)
                    if let info = try? File.System.Stat.info(at: entryPath),
                        info.type == .directory
                    {
                        try _walk(at: entryPath, options: options, depth: depth + 1, entries: &entries)
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

// MARK: - CustomStringConvertible for Error

extension File.Directory.Walk.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .walkFailed(let errno, let message):
            return "Walk failed: \(message) (errno=\(errno))"
        case .undecodableEntry(let parent, let name):
            return "Undecodable entry in \(parent): \(name.debugDescription)"
        }
    }
}
