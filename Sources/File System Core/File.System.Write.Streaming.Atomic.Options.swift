import Kernel

extension File.System.Write.Streaming.Atomic {

    public struct Options: Sendable {

        public var strategy: Strategy

        public var durability: File.System.Write.Durability

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Durability = .full
        ) {
            self.strategy = strategy
            self.durability = durability
        }
    }
}
