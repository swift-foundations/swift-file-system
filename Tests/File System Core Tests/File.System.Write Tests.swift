//
//  File.System.Write Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Test.Unit {
    // File.System.Write is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Write namespace exists`() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Write.self
        _ = File.System.Write.Append.self
        _ = File.System.Write.Atomic.self
        _ = File.System.Write.Streaming.self
    }
}
