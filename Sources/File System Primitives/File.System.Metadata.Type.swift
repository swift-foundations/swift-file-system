//
//  File.System.Metadata.Kind.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Metadata {
    /// File type classification.
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
