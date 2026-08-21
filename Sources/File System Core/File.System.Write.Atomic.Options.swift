import Kernel

extension File.System.Write.Atomic {

    public struct Options: Sendable {

        public var strategy: Strategy

        public var durability: File.System.Write.Durability

        public var preservation: Preservation

        public var ownership: Ownership

        public init(
            strategy: Strategy = .replaceExisting,
            durability: File.System.Write.Durability = .full,
            preservation: Preservation = .permissions,
            ownership: Ownership = .ignore
        ) {
            self.strategy = strategy
            self.durability = durability
            self.preservation = preservation
            self.ownership = ownership
        }
    }
}
