extension File {

    public var parent: File? {
        path.parent.map(Self.init)
    }

    public var name: File.Path.Component {
        path.components.last ?? "."
    }

    public var `extension`: File.Path.Component.Extension? {
        path.extension
    }

    public var stem: File.Path.Component.Stem? {
        path.stem
    }

    public func appending(_ component: File.Path.Component) -> File {
        File(path / component)
    }

    public static func / (lhs: File, rhs: File.Path.Component) -> File {
        lhs.appending(rhs)
    }
}

extension File: CustomStringConvertible {
    public var description: Swift.String {
        Swift.String(path)
    }
}

extension File: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "File(\(Swift.String(path).debugDescription))"
    }
}

extension File {

    public var link: Link {
        Link(path: path)
    }

    public struct Link: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(path: File.Path) {
            self.path = path
        }
    }
}

extension File.Link {

    public func symbolic(to target: File.Path) throws(File.System.Link.Symbolic.Error) {
        try File.System.Link.Symbolic.create(at: path, pointingTo: target)
    }

    public func symbolic(to target: File) throws(File.System.Link.Symbolic.Error) {
        try File.System.Link.Symbolic.create(at: path, pointingTo: target.path)
    }

    public func hard(to existing: File.Path) throws(File.System.Link.Hard.Error) {
        try File.System.Link.Hard.create(at: path, to: existing)
    }

    public func hard(to existing: File) throws(File.System.Link.Hard.Error) {
        try File.System.Link.Hard.create(at: path, to: existing.path)
    }

    public var target: Target { Target(link: self) }
}

extension File.Link {

    public struct Target: Sendable {
        let link: File.Link
    }
}

extension File.Link.Target {

    public var path: File.Path {
        get throws(File.System.Link.Read.Target.Error) {
            try File.System.Link.Read.Target.target(of: link.path)
        }
    }

    public var file: File {
        get throws(File.System.Link.Read.Target.Error) {
            File(try File.System.Link.Read.Target.target(of: link.path))
        }
    }
}
