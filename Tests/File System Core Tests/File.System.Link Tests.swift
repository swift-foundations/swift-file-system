//
//  File.System.Link Tests.swift
//  swift-file-system
//

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

// MARK: - Unit Tests

extension File.System.Link.Test.Unit {
    // File.System.Link is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Link namespace exists`() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Link.self
        _ = File.System.Link.Hard.self
        _ = File.System.Link.Symbolic.self
        _ = File.System.Link.Read.Target.self
    }
}
