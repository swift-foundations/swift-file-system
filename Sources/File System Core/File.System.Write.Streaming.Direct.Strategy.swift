import Kernel

extension File.System.Write.Streaming.Direct {

    public enum Strategy: Sendable {

        case create

        case truncate
    }
}
