extension File.Directory {

    public struct Entry: Sendable {

        public let name: File.Name

        public let parent: File.Path

        public let type: Kind

        public init(name: File.Name, parent: File.Path, type: Kind) {
            self.name = name
            self.parent = parent
            self.type = type
        }
    }
}

extension File.Directory.Entry {

    @inlinable
    public func path() throws(Paths.Path.Component.Error) -> File.Path {
        parent / (try name.asPathComponent())
    }

    @inlinable
    public var pathIfValid: File.Path? {
        do throws(Paths.Path.Component.Error) {
            return try path()
        } catch {
            return nil
        }
    }
}
