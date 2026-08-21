import Kernel

extension File.System.Write.Streaming.Direct {

    public struct Options: Sendable {

        public var strategy: Strategy

        public var durability: File.System.Write.Durability

        public var expectedSize: Int64?

        public init(
            strategy: Strategy = .truncate,
            durability: File.System.Write.Durability = .full,
            expectedSize: Int64? = nil
        ) {
            self.strategy = strategy
            self.durability = durability
            self.expectedSize = expectedSize
        }
    }
}
