// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

extension File.System.Write.Atomic {
    /// Metadata to preserve from the original file during atomic write.
    public struct Preservation: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Preserve file permissions (mode bits).
        public static let permissions = Self(rawValue: 1 << 0)

        /// Preserve file timestamps (access and modification times).
        public static let timestamps = Self(rawValue: 1 << 1)

        /// Preserve extended attributes.
        public static let extendedAttributes = Self(rawValue: 1 << 2)

        /// Preserve access control lists.
        public static let acls = Self(rawValue: 1 << 3)

        /// Preserve all supported metadata.
        public static let all: Preservation = [
            .permissions, .timestamps, .extendedAttributes, .acls,
        ]
    }
}
