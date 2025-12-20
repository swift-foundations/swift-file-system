//
//  File.System.Write.Atomic.Commit Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Commit {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Commit.Test.Unit {
    // File.System.Write.Atomic.Commit is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Commit namespace exists")
    func commitNamespaceExists() {
        _ = File.System.Write.Atomic.Commit.self
        _ = File.System.Write.Atomic.Commit.Phase.self
    }
}
