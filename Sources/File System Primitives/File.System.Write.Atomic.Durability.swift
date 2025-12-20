//
//  File.System.Write.Atomic.Durability.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File.System.Write.Atomic {
    /// Controls the durability guarantees for file synchronization.
    ///
    /// Higher durability modes provide stronger crash-safety but slower performance.
    public enum Durability: Sendable {
        /// Full synchronization with F_FULLFSYNC on macOS (default).
        ///
        /// Guarantees data is written to physical storage and survives power loss.
        /// Slowest but safest option.
        case full

        /// Data-only synchronization without metadata sync where available.
        ///
        /// Uses fdatasync() on Linux or F_BARRIERFSYNC on macOS if available.
        /// Faster than `.full` but still durable for most use cases.
        /// Falls back to fsync if platform-specific optimizations unavailable.
        case dataOnly

        /// No synchronization - data may be buffered in OS caches.
        ///
        /// Fastest option but provides no crash-safety guarantees.
        /// Suitable for caches, temporary files, or build artifacts.
        case none
    }
}

// MARK: - RawRepresentable

extension File.System.Write.Atomic.Durability: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .full: return 0
        case .dataOnly: return 1
        case .none: return 2
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .full
        case 1: self = .dataOnly
        case 2: self = .none
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.System.Write.Atomic.Durability: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
