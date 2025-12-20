//
//  File.System.Write.Streaming.Atomic Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Atomic {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Test.Unit {
    // File.System.Write.Streaming.Atomic is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Atomic namespace exists")
    func atomicNamespaceExists() {
        _ = File.System.Write.Streaming.Atomic.self
        _ = File.System.Write.Streaming.Atomic.Options.self
        _ = File.System.Write.Streaming.Atomic.Strategy.self
    }
}
