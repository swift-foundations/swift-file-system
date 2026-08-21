public import Kernel

extension File.System.IO {

    public enum Error: Swift.Error, Sendable {

        case open(Kernel.File.Open.Error)

        case stat(Kernel.File.Stats.Error)

        case read(Kernel.IO.Read.Error)

        case write(Kernel.IO.Write.Error)

        case cancelled

        case platform(Error_Primitives.Error.Code)
    }
}
