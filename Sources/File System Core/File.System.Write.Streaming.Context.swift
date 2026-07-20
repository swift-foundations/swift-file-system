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

extension File.System.Write.Streaming {
    /// Context for multi-phase streaming writes.
    ///
    /// This struct holds the state needed for the open → write → commit flow.
    /// All fields are immutable after initialization.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let context = try File.System.Write.Streaming.open(path: path, options: options)
    /// try File.System.Write.Streaming.write(chunk: span, to: context)
    /// try File.System.Write.Streaming.commit(context)
    /// ```
    ///
    /// ## Cleanup
    ///
    /// If an error occurs during write, call `cleanup(context)` to close the
    /// file descriptor and remove any temp file.
    ///
    /// ## Threading
    ///
    /// Context is `Sendable` but operations on it should be sequential.
    /// The descriptor and paths are stable after creation.
    public struct Context: ~Copyable, Sendable {
        /// The file descriptor for the open file.
        /// Closes via its own deinit when the context drops.
        ///
        /// Stored non-optionally: nothing extracts it (commit relies on
        /// context destruction), and the borrowed-Optional force-unwrap
        /// (`descriptor!`) is the SIL shape behind the §A23 ownership-
        /// verifier abort on the Windows asserts toolchain — a plain
        /// field projection avoids the class entirely.
        public var descriptor: Kernel.Descriptor

        /// Path for the temp file (nil for direct mode).
        ///
        /// In atomic mode, we write to a temp file first, then rename.
        /// In direct mode, we write directly to the destination.
        public let tempPath: File.Path?

        /// The resolved destination path.
        public let resolvedPath: File.Path

        /// The parent directory path (for directory sync).
        public let parentPath: File.Path

        /// The durability setting for this write.
        public let durability: File.System.Write.Durability

        /// Whether this is an atomic write (temp file + rename).
        public let isAtomic: Bool

        /// The atomic strategy (nil for direct mode).
        public let strategy: Atomic.Strategy?

        public init(
            descriptor: consuming Kernel.Descriptor,
            tempPath: File.Path?,
            resolvedPath: File.Path,
            parentPath: File.Path,
            durability: File.System.Write.Durability,
            isAtomic: Bool,
            strategy: Atomic.Strategy?
        ) {
            self.descriptor = consume descriptor
            self.tempPath = tempPath
            self.resolvedPath = resolvedPath
            self.parentPath = parentPath
            self.durability = durability
            self.isAtomic = isAtomic
            self.strategy = strategy
        }
    }
}
