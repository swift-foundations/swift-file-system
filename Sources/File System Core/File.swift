public struct File: Hashable, Sendable {

    public let path: Self.Path

    public init(_ path: Self.Path) {
        self.path = path
    }
}
