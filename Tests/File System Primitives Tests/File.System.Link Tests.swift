//
//  File.System.Link Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Link {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Link.Test.Unit {
    // File.System.Link is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Link namespace exists")
    func linkNamespaceExists() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Link.self
        _ = File.System.Link.Hard.self
        _ = File.System.Link.Symbolic.self
        _ = File.System.Link.Read.Target.self
    }
}
