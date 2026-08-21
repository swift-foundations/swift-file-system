import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Direct {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Streaming.Direct.Test.Unit {

    @Test
    func `Direct namespace exists`() {
        _ = File.System.Write.Streaming.Direct.self
        _ = File.System.Write.Streaming.Direct.Options.self
        _ = File.System.Write.Streaming.Direct.Strategy.self
    }
}
