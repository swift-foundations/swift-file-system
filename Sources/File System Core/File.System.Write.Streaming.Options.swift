import Kernel

extension File.System.Write.Streaming {

    public struct Options: Sendable {

        public var commit: Commit.Policy

        public init(
            commit: Commit.Policy = .atomic(.init())
        ) {
            self.commit = commit
        }
    }
}
