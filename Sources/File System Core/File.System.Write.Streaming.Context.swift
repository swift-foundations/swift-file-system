public import Kernel

extension File.System.Write.Streaming {

    public struct Context: ~Copyable, Sendable {

        public var descriptor: Kernel.Descriptor

        public let tempPath: File.Path?

        public let resolvedPath: File.Path

        public let parentPath: File.Path

        public let durability: File.System.Write.Durability

        public let isAtomic: Bool

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
