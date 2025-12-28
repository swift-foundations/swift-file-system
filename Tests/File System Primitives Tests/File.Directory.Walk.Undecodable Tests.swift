//
//  File.Directory.Walk.Undecodable Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Walk.Undecodable {
    #TestSuites
}

#if os(macOS) || os(Linux)

    // MARK: - Unit Tests
    //
    // File.Directory.Walk.Undecodable is a namespace enum containing:
    // - Policy: Enum for handling undecodable entries (skip, emit, stopAndThrow)
    // - Context: Struct providing information about undecodable entries
    //
    // See File.Directory.Walk.Undecodable.Policy Tests.swift and
    // File.Directory.Walk.Undecodable.Context Tests.swift for comprehensive tests.

    extension File.Directory.Walk.Undecodable.Test.Unit {

        @Test("Undecodable is a namespace for Policy and Context")
        func namespaceContainsNestedTypes() {
            // Verify the namespace contains the expected nested types by instantiating them
            let _: File.Directory.Walk.Undecodable.Policy = .skip
            let _: File.Directory.Walk.Undecodable.Context.Type = File.Directory.Walk.Undecodable
                .Context.self

            // If this compiles, the namespace structure is correct
            #expect(Bool(true))
        }

        @Test("Policy type is accessible through Undecodable namespace")
        func policyAccessible() {
            // All three policy cases should be accessible
            let policies: [File.Directory.Walk.Undecodable.Policy] = [
                .skip,
                .emit,
                .stopAndThrow,
            ]
            #expect(policies.count == 3)
        }

        @Test("Context type is accessible through Undecodable namespace")
        func contextAccessible() {
            // Context should be constructible through the namespace
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
