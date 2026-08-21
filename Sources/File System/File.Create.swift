public import Kernel

extension File {

    public struct Create: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Create {

    @discardableResult
    @inlinable
    public func touch() throws(File.Handle.Open.Error<Never>) -> File {
        try File.Handle.open(path, options: [.create]).readWrite { _ in }
        return File(path)
    }

    @discardableResult
    @inlinable
    public func touch() async throws(File.Handle.Open.Error<Never>) -> File {
        try File.Handle.open(path, options: [.create]).readWrite { _ in }
        return File(path)
    }
}

extension File {

    public var create: Create {
        Create(path)
    }
}
