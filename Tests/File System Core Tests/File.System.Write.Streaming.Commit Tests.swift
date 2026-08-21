import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Commit {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Streaming.Commit.Test.Unit {

    @Test
    func `Commit namespace exists`() {
        _ = File.System.Write.Streaming.Commit.self
        _ = File.System.Write.Streaming.Commit.Policy.self
    }
}
