public import Kernel

extension File.Handle {

    @inlinable
    public mutating func position() throws(Kernel.File.Seek.Error) -> Int64 {
        try seek(to: 0, from: .current)
    }

    @discardableResult
    @inlinable
    public mutating func rewind() throws(Kernel.File.Seek.Error) -> Int64 {
        try seek(to: 0, from: .start)
    }

}
