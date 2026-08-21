extension File.Directory.Walk {

    public struct Options: Sendable {

        public var maxDepth: Int?

        public var followSymlinks: Bool

        public var includeHidden: Bool

        public var onUndecodable: @Sendable (Undecodable.Context) -> Undecodable.Policy

        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true,
            onUndecodable: @escaping @Sendable (Undecodable.Context) -> Undecodable.Policy = { _ in
                .skip
            }
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
            self.onUndecodable = onUndecodable
        }
    }
}
