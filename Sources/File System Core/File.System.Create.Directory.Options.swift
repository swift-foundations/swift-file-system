extension File.System.Create.Directory {

    public struct Options: Sendable {

        public var permissions: File.System.Metadata.Permissions?

        public init(
            permissions: File.System.Metadata.Permissions? = nil
        ) {
            self.permissions = permissions
        }
    }
}
