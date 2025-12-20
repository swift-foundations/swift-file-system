//
//  File.System.Metadata.ACL Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Metadata.ACL {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Metadata.ACL.Test.Unit {
    // File.System.Metadata.ACL is a namespace enum with no cases (TODO implementation)
    // Tests verify the namespace exists

    @Test("ACL namespace exists")
    func aclNamespaceExists() {
        // Verify the namespace type is accessible
        _ = File.System.Metadata.ACL.self
    }
}
