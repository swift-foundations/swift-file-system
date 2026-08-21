import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Walk.Undecodable {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)

    extension File.Directory.Walk.Undecodable.Test.Unit {

        @Test
        func `Undecodable is a namespace for Policy and Context`() {

            let _: File.Directory.Walk.Undecodable.Policy = .skip
            let _: File.Directory.Walk.Undecodable.Context.Type = File.Directory.Walk.Undecodable
                .Context.self

            #expect(Bool(true))
        }

        @Test
        func `Policy type is accessible through Undecodable namespace`() {

            let policies: [File.Directory.Walk.Undecodable.Policy] = [
                .skip,
                .emit,
                .stopAndThrow,
            ]
            #expect(policies.count == 3)
        }

        @Test
        func `Context type is accessible through Undecodable namespace`() {

            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: [0x80])
            let context = File.Directory.Walk.Undecodable.Context(
                parent: parent,
                name: name,
                type: .file,
                depth: 0
            )
            #expect(context.parent == parent)
        }
    }
#endif
