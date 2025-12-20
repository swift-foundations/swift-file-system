//
//  File.System.Metadata Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Metadata {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Metadata.Test.Unit {
    // File.System.Metadata is a namespace enum with no cases
    // Tests verify the namespace exists and nested types are accessible

    @Test("Metadata namespace exists")
    func metadataNamespaceExists() {
        // Verify nested types are accessible through the namespace
        _ = File.System.Metadata.Kind.self
        _ = File.System.Metadata.Permissions.self
        _ = File.System.Metadata.Ownership.self
        _ = File.System.Metadata.Timestamps.self
        _ = File.System.Metadata.Info.self
    }
}
