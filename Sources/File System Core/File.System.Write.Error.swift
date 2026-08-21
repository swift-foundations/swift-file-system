import Kernel

extension File.System.Write {

    internal enum Error: Swift.Error, Sendable {
        case sync(Swift.String)
        case close(Swift.String)
        case rename(from: File.Path, to: File.Path, Swift.String)
        case exists(path: File.Path)
        case directory(path: File.Path, Swift.String)
        case write(written: Int, expected: Int, Swift.String)
        case random(Swift.String)
    }
}
