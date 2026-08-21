public import Kernel

extension File.Handle {

    public enum Error: Swift.Error, Sendable {

        case write(Kernel.IO.Write.Error)

        case shortWrite(written: Int, expected: Int)
    }
}

extension File.Handle.Error {

    public var isShortWrite: Bool {
        if case .shortWrite = self { return true }
        return false
    }
}

extension File.Handle {

    @usableFromInline
    internal static func advance(
        totalWritten: Int,
        by writtenThisCall: Int,
        expected: Int
    ) throws(File.Handle.Error) -> Int {
        guard writtenThisCall > 0 else {
            throw .shortWrite(written: totalWritten, expected: expected)
        }
        return totalWritten + writtenThisCall
    }
}

extension File.Handle.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .write(let error):
            return "Write failed: \(error)"

        case .shortWrite(let written, let expected):
            return "Short write: wrote \(written) of \(expected) bytes, write() returned 0"
        }
    }
}
