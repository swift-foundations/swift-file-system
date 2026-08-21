import Kernel
import Testing

@testable import File_System_Core

extension File.System.Link {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Link.Test.Unit {

    @Test
    func `Link namespace exists`() {

        _ = File.System.Link.self
        _ = File.System.Link.Hard.self
        _ = File.System.Link.Symbolic.self
        _ = File.System.Link.Read.Target.self
    }
}
