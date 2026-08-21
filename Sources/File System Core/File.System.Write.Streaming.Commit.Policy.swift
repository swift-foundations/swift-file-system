import Kernel

extension File.System.Write.Streaming.Commit {

    public enum Policy: Sendable {

        case atomic(File.System.Write.Streaming.Atomic.Options = .init())

        case direct(File.System.Write.Streaming.Direct.Options = .init())
    }
}
