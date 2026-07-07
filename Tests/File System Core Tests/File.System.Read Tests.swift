//
//  File.System.Read Tests.swift
//  swift-file-system
//

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

// MARK: - Unit Tests

extension File.System.Read.Test.Unit {
    // File.System.Read is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Read namespace exists`() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Read.self
        _ = File.System.Read.Full.self
    }
}
