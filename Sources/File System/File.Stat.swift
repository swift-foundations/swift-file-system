public import Kernel

extension File {

    public struct Stat: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Stat {

    @inlinable
    public var exists: Bool {
        File.System.Stat.exists(at: path)
    }

    @inlinable
    public var isFile: Bool {
        File.System.Stat.isFile(at: path)
    }

    @inlinable
    public var isDirectory: Bool {
        File.System.Stat.isDirectory(at: path)
    }

    @inlinable
    public var isSymlink: Bool {
        File.System.Stat.isSymlink(at: path)
    }

    @inlinable
    public var info: File.System.Metadata.Info {
        get throws(Kernel.File.Stats.Error) {
            try File.System.Stat.info(at: path)
        }
    }

    @inlinable
    public var size: Kernel.File.Size {
        get throws(Kernel.File.Stats.Error) {
            try info.size
        }
    }

    @inlinable
    public var permissions: File.System.Metadata.Permissions {
        get throws(Kernel.File.Stats.Error) {
            try info.permissions
        }
    }

    @inlinable
    public var isEmpty: Bool {
        get throws(Kernel.File.Stats.Error) {
            try size.isZero
        }
    }
}

extension File {

    public var stat: Stat {
        Stat(path)
    }
}
