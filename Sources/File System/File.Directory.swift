extension File.Directory {

    public subscript(_ name: File.Path.Component) -> File {
        File(path / name)
    }

    public subscript(file name: File.Path.Component) -> File {
        File(path / name)
    }

    public subscript(directory name: File.Path.Component) -> File.Directory {
        File.Directory(path / name)
    }

    public func subdirectory(_ name: File.Path.Component) -> File.Directory {
        File.Directory(path / name)
    }
}

extension File.Directory {

    public var parent: File.Directory? {
        path.parent.map(Self.init)
    }

    public var name: File.Path.Component {
        path.components.last ?? "."
    }

    public func appending(_ component: File.Path.Component) -> File.Directory {
        File.Directory(path / component)
    }

    public static func / (lhs: File.Directory, rhs: File.Path.Component) -> File.Directory {
        lhs.appending(rhs)
    }
}

extension File.Directory: CustomStringConvertible {
    public var description: Swift.String {
        Swift.String(path)
    }
}

extension File.Directory: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "File.Directory(\(Swift.String(path).debugDescription))"
    }
}
