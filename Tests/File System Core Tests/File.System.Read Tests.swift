import Kernel
import Testing

@testable import File_System_Core

extension File.System.Read {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Read.Test.Unit {

    @Test
    func `Read namespace exists`() {

        _ = File.System.Read.self
        _ = File.System.Read.Full.self
    }
}
