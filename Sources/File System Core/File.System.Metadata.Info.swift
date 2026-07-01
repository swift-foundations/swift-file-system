//
//  File.System.Metadata.Info.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File.System.Metadata {
    /// File metadata information (stat result).
    ///
    /// Fields preserve Kernel typed values where possible. For platform-specific
    /// features like birthtime/creationTime, use:
    /// - `Darwin.File.Stats.birthtime` from swift-darwin-primitives
    /// - `Windows.File.Stats.creationTime` from swift-windows-primitives
    public struct Info: Sendable {
        /// File size in bytes.
        public let size: Kernel.File.Size

        /// File permissions.
        public let permissions: Permissions

        /// File ownership.
        public let owner: Ownership

        /// Last access time.
        public let accessTime: Kernel.Time

        /// Last modification time.
        public let modificationTime: Kernel.Time

        /// Status change time.
        public let changeTime: Kernel.Time

        /// File type.
        public let type: Kind

        /// Inode number.
        public let inode: Kernel.Inode

        /// Device ID.
        public let device: Kernel.Device

        /// Number of hard links.
        public let linkCount: Kernel.Link.Count

        public init(
            size: Kernel.File.Size,
            permissions: Permissions,
            owner: Ownership,
            accessTime: Kernel.Time,
            modificationTime: Kernel.Time,
            changeTime: Kernel.Time,
            type: Kind,
            inode: Kernel.Inode,
            device: Kernel.Device,
            linkCount: Kernel.Link.Count
        ) {
            self.size = size
            self.permissions = permissions
            self.owner = owner
            self.accessTime = accessTime
            self.modificationTime = modificationTime
            self.changeTime = changeTime
            self.type = type
            self.inode = inode
            self.device = device
            self.linkCount = linkCount
        }
    }
}
