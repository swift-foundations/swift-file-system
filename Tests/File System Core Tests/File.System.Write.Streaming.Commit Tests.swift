//
//  File.System.Write.Streaming.Commit Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Commit {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Commit.Test.Unit {
    // File.System.Write.Streaming.Commit is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Commit namespace exists`() {
        _ = File.System.Write.Streaming.Commit.self
        _ = File.System.Write.Streaming.Commit.Policy.self
    }
}
