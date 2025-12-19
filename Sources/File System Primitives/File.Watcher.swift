//
//  File.Watcher.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Binary

extension File {
    /// File system event watching (future implementation).
    public enum Watcher {
        // TODO: Implementation using FSEvents/inotify
    }
}

extension File.Watcher {
    /// A file system event.
    public struct Event: Sendable {
        /// The path that changed.
        public let path: File.Path

        /// The type of event.
        public let type: EventType

        public init(path: File.Path, type: EventType) {
            self.path = path
            self.type = type
        }
    }

    /// The type of file system event.
    public enum EventType: Sendable {
        case created
        case modified
        case deleted
        case renamed
        case attributesChanged
    }

    /// Options for file watching.
    public struct Options: Sendable {
        /// Whether to watch subdirectories recursively.
        public var recursive: Bool

        /// Latency in seconds before coalescing events.
        public var latency: Double

        public init(
            recursive: Bool = false,
            latency: Double = 0.5
        ) {
            self.recursive = recursive
            self.latency = latency
        }
    }
}

// MARK: - RawRepresentable

extension File.Watcher.EventType: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .created: return 0
        case .modified: return 1
        case .deleted: return 2
        case .renamed: return 3
        case .attributesChanged: return 4
        }
    }

    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .created
        case 1: self = .modified
        case 2: self = .deleted
        case 3: self = .renamed
        case 4: self = .attributesChanged
        default: return nil
        }
    }
}

// MARK: - Binary.Serializable

extension File.Watcher.EventType: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(value.rawValue)
    }
}
