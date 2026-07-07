//
//  File.System.Metadata Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Metadata {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Metadata.Test.Unit {
    // File.System.Metadata is a namespace enum with no cases
    // Tests verify the namespace exists and nested types are accessible

    @Test
    func `Metadata namespace exists`() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Metadata.Kind.self
        _ = File.System.Metadata.Permissions.self
        _ = File.System.Metadata.Ownership.self
        _ = File.System.Metadata.Info.self
    }
}
