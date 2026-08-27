public import Kernel
import Memory
public import Span_Raw

extension File.System.IO {

    public struct Capabilities: Sendable {

        public let open:
            @Sendable (
                borrowing File.Path,
                Kernel.File.Open.Mode
            ) async throws(File.System.IO.Error) -> Kernel.Descriptor

        public let close: @Sendable (consuming Kernel.Descriptor) async -> Void

        public let read:
            @Sendable (
                borrowing Kernel.Descriptor,
                Span.Raw.Mutable
            ) async throws(File.System.IO.Error) -> Int

        public let write:
            @Sendable (
                borrowing Kernel.Descriptor,
                Span.Raw
            ) async throws(File.System.IO.Error) -> Int

        public let stat:
            @Sendable (
                borrowing File.Path
            ) async throws(File.System.IO.Error) -> Kernel.File.Stats

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
