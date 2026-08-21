import Kernel

extension File.System.Write.Atomic {

    public enum Ownership: Sendable, Equatable {

        case preserve(strict: Bool)

        case ignore
    }
}
