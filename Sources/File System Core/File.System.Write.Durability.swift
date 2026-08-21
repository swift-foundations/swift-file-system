import Kernel

extension File.System.Write {

    public enum Durability: UInt8, Sendable, Equatable {

        case full = 0

        case dataOnly = 1

        case none = 2
    }
}
