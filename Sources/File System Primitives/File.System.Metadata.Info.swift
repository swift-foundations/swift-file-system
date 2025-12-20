//
//  File.System.Metadata.Info.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

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

    /// File kind classification.
    public enum Kind: Sendable {
        case regular
        case directory
        case symbolicLink
        case blockDevice
        case characterDevice
        case fifo
        case socket
    }
}

// MARK: - Backward Compatibility

extension File.System.Metadata {
    @available(*, deprecated, renamed: "Kind")
    public typealias FileType = Kind
}

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

// MARK: - RawRepresentable

extension File.System.Metadata.Kind: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .regular: return 0
        case .directory: return 1
        case .symbolicLink: return 2
        case .blockDevice: return 3
        case .characterDevice: return 4
        case .fifo: return 5
        case .socket: return 6
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .regular
        case 1: self = .directory
        case 2: self = .symbolicLink
        case 3: self = .blockDevice
        case 4: self = .characterDevice
        case 5: self = .fifo
        case 6: self = .socket
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Metadata.Kind: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
