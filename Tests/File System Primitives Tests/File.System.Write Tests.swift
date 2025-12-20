//
//  File.System.Write Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Test.Unit {
    // File.System.Write is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Write namespace exists")
    func writeNamespaceExists() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Write.self
        _ = File.System.Write.Append.self
        _ = File.System.Write.Atomic.self
        _ = File.System.Write.Streaming.self
    }
}
