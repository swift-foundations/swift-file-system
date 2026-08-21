import Kernel

extension File.System.Write.Atomic {

    public enum Strategy: UInt8, Sendable, Equatable {

        case replaceExisting = 0

        case noClobber = 1
    }
}
