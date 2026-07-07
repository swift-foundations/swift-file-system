//
//  File.System.Copy.Recursive.swift
//  swift-file-system
//
//  Created by Claude Code on 13/01/2026.
//

import Kernel
import Strings

// MARK: - Public API

extension File.System.Copy {
    /// Recursively copies a directory from source to destination.
    ///
    /// - Parameters:
    ///   - source: The source directory path.
    ///   - destination: The destination directory path.
    ///   - options: Copy options (overwrite, copyAttributes, followSymlinks).
    /// - Throws: `File.System.Copy.Error` on failure.
    ///
    /// ## Options
    /// - `overwrite`: If destination exists, remove it first before copying.
    /// - `copyAttributes`: Preserve permissions and timestamps.
    /// - `followSymlinks`: If true, copy symlink targets; if false, copy symlinks themselves.
    ///
    /// ## Example
    /// ```swift
    /// try File.System.Copy.recursive(
    ///     from: "/tmp/source",
    ///     to: "/tmp/dest",
    ///     options: .init(overwrite: true)
    /// )
    /// ```
    public static func recursive(
        from source: File.Path,
        to destination: File.Path,
        options: Options = .init()
    ) throws(Error) {
        try copyRecursive(from: source, to: destination, options: options)
    }
}

// MARK: - Implementation

extension File.System.Copy {
    /// Internal recursive copy implementation.
    @usableFromInline
    internal static func copyRecursive(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Error) {
        // Check source - get info to determine type
        let sourceInfo: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            sourceInfo = try File.System.Stat.info(at: source)
        } catch {
            throw .sourceNotFound
        }

        // If source is not a directory, delegate to file copy
        guard sourceInfo.type == .directory else {
            try copy(from: source, to: destination, options: options)
            return
        }

        // Check destination
        if File.System.Stat.exists(at: destination) {
            if !options.overwrite {
                throw .destinationExists
            }
            // Remove existing destination
            do throws(File.System.Delete.Error) {
                try File.System.Delete.delete(
                    at: destination,
                    recursive: true
                )
            } catch {
                throw .operation("Failed to remove existing destination: \(error)")
            }
        }

        // Create destination directory
        do throws(File.System.Create.Directory.Error) {
            try File.System.Create.Directory.create(at: destination)
        } catch {
            throw .operation("Failed to create destination directory: \(error)")
        }

        // Track if we need cleanup on failure
        var success = false
        defer {
            if !success {
                // Best-effort cleanup
                do throws(File.System.Delete.Error) {
                    try File.System.Delete.delete(
                        at: destination,
                        recursive: true
                    )
                } catch {
                    // Best-effort cleanup; ignore failures.
                }
            }
        }

        // Copy directory attributes if requested (permissions)
        // Do this early so files inherit correct parent permissions
        if options.copyAttributes {
            copyDirectoryAttributes(from: source, to: destination)
        }

        // Enumerate and copy contents
        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: File.Directory(source))
        } catch {
            throw mapContentsError(error, source: source)
        }

        for entry in entries {
            // Get source entry path
            guard let sourcePath = entry.pathIfValid else {
                // Skip entries with invalid paths
                continue
            }

            // Build destination path from entry name
            let destPath: File.Path
            do throws(Paths.Path.Component.Error) {
                destPath = destination / (try entry.name.asPathComponent())
            } catch {
                // Skip entries with invalid path components or undecodable names
                continue
            }

            switch entry.type {
            case .file:
                try copy(from: sourcePath, to: destPath, options: options)

            case .directory:
                try copyRecursive(from: sourcePath, to: destPath, options: options)

            case .symbolicLink:
                if options.followSymlinks {
                    // Follow symlink - copy its target
                    try copySymlinkTarget(
                        from: sourcePath,
                        to: destPath,
                        options: options
                    )
                } else {
                    // Copy the symlink itself
                    try copySymlinkRecursive(from: sourcePath, to: destPath)
                }

            case .other:
                // Skip special files (devices, sockets, FIFOs)
                continue
            }
        }

        // Copy directory timestamps if requested (do after contents are copied)
        if options.copyAttributes {
            copyDirectoryTimestamps(from: source, to: destination)
        }

        success = true
    }

    /// Copies a symlink target (following the symlink to copy its contents).
    private static func copySymlinkTarget(
        from source: File.Path,
        to destination: File.Path,
        options: Options
    ) throws(Error) {
        // Stat the symlink target to determine its type
        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: source)
        } catch {
            // Broken symlink - skip or throw
            throw .sourceNotFound
        }

        switch info.type {
        case .directory:
            try copyRecursive(from: source, to: destination, options: options)

        case .regular:
            try copy(from: source, to: destination, options: options)

        default:
            // Skip other types
            break
        }
    }
}

// MARK: - Symlink Copy

#if !os(Windows)
    extension File.System.Copy {
        /// Copies a symlink by reading its target and creating a new symlink.
        private static func copySymlinkRecursive(
            from source: File.Path,
            to destination: File.Path
        ) throws(Error) {
            // Read the symlink target using Kernel API
            let target: Swift.String
            do throws(Kernel.Link.Symbolic.Error) {
                let kernelString = try Kernel.Link.Symbolic.readTarget(at: source.kernelPath)
                target = Swift.String(kernelString.view)
            } catch {
                throw .operation("symlink read failed: \(error)")
            }

            // Create symlink at destination using Kernel API
            do throws(Kernel.Link.Symbolic.Error) {
                let targetPath: File.Path
                do throws(File.Path.Error) {
                    targetPath = try File.Path(target)
                } catch {
                    throw Kernel.Link.Symbolic.Error.notFound
                }
                try Kernel.Link.Symbolic.create(target: targetPath.kernelPath, at: destination.kernelPath)
            } catch {
                throw .operation("symlink create failed: \(error)")
            }
        }
    }
#else
    extension File.System.Copy {
        /// Copies a symlink on Windows (stub - creates a copy of the target instead).
        private static func copySymlinkRecursive(
            from source: File.Path,
            to destination: File.Path
        ) throws(Error) {
            // Windows symlinks require special handling and elevated privileges.
            // For now, we copy the target contents instead of the symlink itself.
            try copySymlinkTarget(
                from: source,
                to: destination,
                options: .init(followSymlinks: true)
            )
        }
    }
#endif

// MARK: - Attribute Copying

extension File.System.Copy {
    /// Copies directory permissions (best effort).
    private static func copyDirectoryAttributes(
        from source: File.Path,
        to destination: File.Path
    ) {
        #if !os(Windows)
            // Get source permissions
            let sourceInfo: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                sourceInfo = try File.System.Stat.info(at: source)
            } catch {
                return
            }

            // Set destination permissions using Kernel API
            do throws(Kernel.File.Attributes.Error) {
                let kernelPermissions = Kernel.File.Permissions(rawValue: sourceInfo.permissions.rawValue)
                try Kernel.File.Attributes.set(kernelPermissions, at: destination.kernelPath)
            } catch {
                // Best effort - ignore errors
            }
        #endif
    }

    /// Copies directory timestamps (best effort).
    private static func copyDirectoryTimestamps(
        from source: File.Path,
        to destination: File.Path
    ) {
        #if !os(Windows)
            // Get source timestamps
            let sourceInfo: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                sourceInfo = try File.System.Stat.info(at: source)
            } catch {
                return
            }

            // Set destination timestamps using Kernel API
            do throws(Kernel.File.Times.Error) {
                try Kernel.File.Times.set(
                    access: sourceInfo.accessTime,
                    modification: sourceInfo.modificationTime,
                    at: destination.kernelPath
                )
            } catch {
                // Best effort - ignore errors
            }
        #endif
    }
}

// MARK: - Error Mapping

extension File.System.Copy {
    /// Maps File.Directory.Contents.Error to File.System.Copy.Error.
    private static func mapContentsError(
        _ error: File.Directory.Contents.Error,
        source: File.Path
    ) -> File.System.Copy.Error {
        switch error {
        case .pathNotFound:
            return .sourceNotFound

        case .permissionDenied:
            return .permissionDenied

        case .notADirectory:
            return .isDirectory

        case .readFailed(_, let message):
            return .operation("Directory read failed: \(message)")
        }
    }
}
