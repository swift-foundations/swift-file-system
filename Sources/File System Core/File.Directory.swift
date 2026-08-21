extension File {

    public struct Directory: Hashable, Sendable {

        public let path: File.Path

        public init(_ path: File.Path) {
            self.path = path
        }

        public init(validating string: Swift.String) throws(Paths.Path.Error) {
            self.path = try File.Path(string)
        }
    }
}
