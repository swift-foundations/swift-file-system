extension File.Directory.Walk.Undecodable {

    public struct Context: Sendable {

        public let parent: File.Path

        public let name: File.Name

        public let type: File.Directory.Entry.Kind

        public let depth: Int

        public init(
            parent: File.Path,
            name: File.Name,
            type: File.Directory.Entry.Kind,
            depth: Int
        ) {
            self.parent = parent
            self.name = name
            self.type = type
            self.depth = depth
        }
    }
}
