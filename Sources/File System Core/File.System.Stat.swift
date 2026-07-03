//
//  File.System.Stat.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System {
    /// File status and existence checks.
    public enum Stat {}
}

// MARK: - Core API

extension File.System.Stat {
    /// Gets file metadata information.
    ///
    /// - Parameters:
    ///   - path: The path to stat.
    ///   - followSymlinks: If `true` (the default), follows symlinks and returns info
    ///     about the target. If `false`, returns info about the link itself.
    /// - Returns: File metadata information.
    /// - Throws: `Kernel.File.Stats.Error` on failure.
    @inlinable
    public static func info(
        at path: borrowing File.Path,
        followSymlinks: Bool = true
    ) throws(Kernel.File.Stats.Error) -> File.System.Metadata.Info {
        let stats =
            followSymlinks
            ? try Kernel.File.Stats.get(path: path.kernelPath)
            : try Kernel.File.Stats.lget(path: path.kernelPath)
        return makeInfo(from: stats)
    }

    /// Checks if a path exists.
    ///
    /// - Parameter path: The path to check.
    /// - Returns: `true` if the path exists, `false` otherwise.
    @inlinable
    public static func exists(at path: borrowing File.Path) -> Bool {
        do {
            _ = try Kernel.File.Stats.get(path: path.kernelPath)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Kernel Mapping

extension File.System.Stat {
    /// Creates Info from Kernel.File.Stats.
    @usableFromInline
    internal static func makeInfo(from stats: Kernel.File.Stats) -> File.System.Metadata.Info {
        let fileType: File.System.Metadata.Kind
        switch stats.type {
        case .regular:
            fileType = .regular

        case .directory:
            fileType = .directory

        case .link:
            fileType = .symbolicLink

        case .device(.block):
            fileType = .blockDevice

        case .device(.character):
            fileType = .characterDevice

        case .fifo:
            fileType = .fifo

        case .socket:
            fileType = .socket

        case .unknown:
            fileType = .regular
        }

        return File.System.Metadata.Info(
            size: stats.size,
            permissions: File.System.Metadata.Permissions(rawValue: stats.permissions.rawValue),
            owner: File.System.Metadata.Ownership(uid: stats.uid, gid: stats.gid),
            accessTime: stats.accessTime,
            modificationTime: stats.modificationTime,
            changeTime: stats.changeTime,
            type: fileType,
            inode: stats.inode,
            device: stats.device,
            linkCount: stats.linkCount
        )
    }
}
