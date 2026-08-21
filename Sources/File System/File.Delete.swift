public import IO
public import Thread_Pool

extension File {

    public struct Delete: Sendable {

        public let path: File.Path

        @usableFromInline
        internal init(_ path: File.Path) {
            self.path = path
        }
    }
}

extension File.Delete {

    @inlinable
    public func callAsFunction() throws(File.System.Delete.Error) {
        try File.System.Delete.delete(at: path)
    }

    @inlinable
    public func callAsFunction() async throws(Either<
        Kernel.Thread.Pool.Error, File.System.Delete.Error
    >) {
        let path = self.path
        try await Kernel.Thread.Pool.shared.run { () throws(File.System.Delete.Error) in
            try File.System.Delete.delete(at: path)
        }
    }

    @inlinable
    public func ifExists() throws(File.System.Delete.Error) {
        do throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path)
        } catch {
            if error.isNotFound {
                return
            }
            throw error
        }
    }

    @inlinable
    public func ifExists() async throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>)
    {
        let path = self.path
        do throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
            try await Kernel.Thread.Pool.shared.run { () throws(File.System.Delete.Error) in
                try File.System.Delete.delete(at: path)
            }
        } catch {
            if case .right(let deleteError) = error, deleteError.isNotFound {
                return
            }
            throw error
        }
    }
}

extension File {

    public var delete: Delete {
        Delete(path)
    }
}
