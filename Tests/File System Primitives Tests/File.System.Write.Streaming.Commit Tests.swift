//
//  File.System.Write.Streaming.Commit Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Commit {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Commit.Test.Unit {
    // File.System.Write.Streaming.Commit is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Commit namespace exists")
    func commitNamespaceExists() {
        _ = File.System.Write.Streaming.Commit.self
        _ = File.System.Write.Streaming.Commit.Policy.self
    }
}
