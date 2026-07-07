//
//  File.System.Write.Streaming.Direct Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Direct {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Direct.Test.Unit {
    // File.System.Write.Streaming.Direct is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test
    func `Direct namespace exists`() {
        _ = File.System.Write.Streaming.Direct.self
        _ = File.System.Write.Streaming.Direct.Options.self
        _ = File.System.Write.Streaming.Direct.Strategy.self
    }
}
