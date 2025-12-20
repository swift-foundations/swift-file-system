//
//  File.System.Read.Buffered Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Read.Buffered {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Read.Buffered.Test.Unit {
    // File.System.Read.Buffered is a namespace enum (TODO implementation)
    // Tests verify the namespace exists

    @Test("Buffered namespace exists")
    func bufferedNamespaceExists() {
        _ = File.System.Read.Buffered.self
    }
}
