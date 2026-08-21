public import IO
public import Thread_Pool

extension File.Directory {

    public struct Entries: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Directory.Entries {

    @inlinable
    public func callAsFunction() throws(File.Directory.Contents.Error) -> [File.Directory.Entry] {
        try File.Directory.Contents.list(at: File.Directory(path))
    }

    @inlinable
    public func callAsFunction() async throws(Either<
        Kernel.Thread.Pool.Error, File.Directory.Contents.Error
    >) -> [File.Directory.Entry] {
        let path = self.path
        return try await Kernel.Thread.Pool.shared.run { () throws(File.Directory.Contents.Error) in
            try File.Directory.Contents.list(at: File.Directory(path))
        }
    }
}

extension File.Directory {

    public var entries: Entries {
        Entries(path)
    }
}
