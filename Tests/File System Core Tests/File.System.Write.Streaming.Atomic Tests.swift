//
//  File.System.Write.Streaming.Atomic Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Atomic {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Test.Unit {
    // File.System.Write.Streaming.Atomic is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Atomic namespace exists`() {
        _ = File.System.Write.Streaming.Atomic.self
        _ = File.System.Write.Streaming.Atomic.Options.self
        _ = File.System.Write.Streaming.Atomic.Strategy.self
    }
}
