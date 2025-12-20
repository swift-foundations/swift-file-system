//
//  File.System.Read Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Read {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Read.Test.Unit {
    // File.System.Read is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Read namespace exists")
    func readNamespaceExists() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Read.self
        _ = File.System.Read.Full.self
        _ = File.System.Read.Buffered.self
        _ = File.System.Read.Streaming.self
    }
}
