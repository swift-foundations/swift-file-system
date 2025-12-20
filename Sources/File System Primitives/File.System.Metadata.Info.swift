//
//  File.System.Metadata.Info.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Metadata {
    /// File metadata information (stat result).
    public struct Info: Sendable {
        /// File size in bytes.
        public let size: Int64

        /// File permissions.
        public let permissions: Permissions

        /// File ownership.
        public let owner: Ownership

        /// File timestamps.
        public let timestamps: Timestamps

        /// File kind.
        public let kind: Kind

        /// Inode number.
        public let inode: UInt64

        /// Device ID.
        public let deviceId: UInt64

        /// Number of hard links.
        public let linkCount: UInt32

        public init(
            size: Int64,
            permissions: Permissions,
            owner: Ownership,
            timestamps: Timestamps,
            kind: Kind,
            inode: UInt64,
            deviceId: UInt64,
            linkCount: UInt32
        ) {
            self.size = size
            self.permissions = permissions
            self.owner = owner
            self.timestamps = timestamps
            self.kind = kind
            self.inode = inode
            self.deviceId = deviceId
            self.linkCount = linkCount
        }
    }
}

// MARK: - Backward Compatibility

extension File.System.Metadata.Info {
    /// Backward compatible property - use `kind` instead.
    @available(*, deprecated, renamed: "kind")
    public var type: File.System.Metadata.Kind { kind }

    /// Backward compatible initializer.
    @available(*, deprecated, message: "Use init(size:permissions:owner:timestamps:kind:inode:deviceId:linkCount:) instead")
    public init(
        size: Int64,
        permissions: File.System.Metadata.Permissions,
        owner: File.System.Metadata.Ownership,
        timestamps: File.System.Metadata.Timestamps,
        type: File.System.Metadata.Kind,
        inode: UInt64,
        deviceId: UInt64,
        linkCount: UInt32
    ) {
        self.init(
            size: size,
            permissions: permissions,
            owner: owner,
            timestamps: timestamps,
            kind: type,
            inode: inode,
            deviceId: deviceId,
            linkCount: linkCount
        )
    }
}
