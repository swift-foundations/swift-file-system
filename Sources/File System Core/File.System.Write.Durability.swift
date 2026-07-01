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

extension File.System.Write {
    /// Controls the durability guarantees for file synchronization.
    ///
    /// Higher durability modes provide stronger crash-safety but slower performance.
    public enum Durability: UInt8, Sendable, Equatable {
        /// Full synchronization with F_FULLFSYNC on macOS (default).
        ///
        /// Guarantees data is written to physical storage and survives power loss.
        /// Slowest but safest option.
        case full = 0

        /// Data-only synchronization without metadata sync where available.
        ///
        /// Uses fdatasync() on Linux or F_BARRIERFSYNC on macOS if available.
        /// Faster than `.full` but still durable for most use cases.
        /// Falls back to fsync if platform-specific optimizations unavailable.
        case dataOnly = 1

        /// No synchronization - data may be buffered in OS caches.
        ///
        /// Fastest option but provides no crash-safety guarantees.
        /// Suitable for caches, temporary files, or build artifacts.
        case none = 2
    }
}
