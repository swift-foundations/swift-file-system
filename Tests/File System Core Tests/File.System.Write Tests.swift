import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Test.Unit {

    @Test
    func `Write namespace exists`() {

        _ = File.System.Write.self
        _ = File.System.Write.Append.self
        _ = File.System.Write.Atomic.self
        _ = File.System.Write.Streaming.self
    }
}
