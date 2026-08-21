import Kernel

extension File.System.Write.Streaming.Atomic {

    public enum Strategy: Sendable {

        case replaceExisting

        case noClobber
    }
}
