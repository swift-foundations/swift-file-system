//
//  File.System.Read.Streaming Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Read.Streaming {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Read.Streaming.Test.Unit {
    // File.System.Read.Streaming is a namespace enum (TODO implementation)
    // Tests verify the namespace exists

    @Test("Streaming namespace exists")
    func streamingNamespaceExists() {
        _ = File.System.Read.Streaming.self
    }
}
