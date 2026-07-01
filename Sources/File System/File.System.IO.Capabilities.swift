//
//  File.System.IO.Capabilities.swift
//  swift-file-system
//

public import Kernel
public import Memory_Primitives
public import Span_Raw_Primitives

extension File.System.IO {
    /// The file-system operation set.
    ///
    /// Five `@Sendable` closures describing the operations every
    /// file-system strategy (blocking / completions) must provide.
    /// Per-strategy factories construct a value of this struct and
    /// pair it with an ``IO/Runner`` via ``IO``'s initializer.
    public struct Capabilities: Sendable {

        /// Open `path` in the given mode and return a descriptor.
        public let open:
            @Sendable (
                borrowing File.Path,
                Kernel.File.Open.Mode
            ) async throws(File.System.IO.Error) -> Kernel.Descriptor

        /// Close a descriptor. Ownership is consumed.
        public let close: @Sendable (consuming Kernel.Descriptor) async -> Void

        /// Read bytes from `fd` into `buffer`. Returns bytes read, or 0
        /// at EOF.
        public let read:
            @Sendable (
                borrowing Kernel.Descriptor,
                Span.Raw.Mutable
            ) async throws(File.System.IO.Error) -> Int

        /// Write bytes from `buffer` to `fd`. Returns bytes written.
        public let write:
            @Sendable (
                borrowing Kernel.Descriptor,
                Span.Raw
            ) async throws(File.System.IO.Error) -> Int

        /// Resolve file metadata for `path`.
        public let stat:
            @Sendable (
                borrowing File.Path
            ) async throws(File.System.IO.Error) -> Kernel.File.Stats

        /// Creates a capability set from its five operation closures.
        public init(
            open:
                @Sendable @escaping (
                    borrowing File.Path,
                    Kernel.File.Open.Mode
                ) async throws(File.System.IO.Error) -> Kernel.Descriptor,
            close: @Sendable @escaping (consuming Kernel.Descriptor) async -> Void,
            read:
                @Sendable @escaping (
                    borrowing Kernel.Descriptor,
                    Span.Raw.Mutable
                ) async throws(File.System.IO.Error) -> Int,
            write:
                @Sendable @escaping (
                    borrowing Kernel.Descriptor,
                    Span.Raw
                ) async throws(File.System.IO.Error) -> Int,
            stat:
                @Sendable @escaping (
                    borrowing File.Path
                ) async throws(File.System.IO.Error) -> Kernel.File.Stats
        ) {
            self.open = open
            self.close = close
            self.read = read
            self.write = write
            self.stat = stat
        }
    }
}
