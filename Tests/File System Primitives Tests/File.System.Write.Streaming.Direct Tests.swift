//
//  File.System.Write.Streaming.Direct Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Direct {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Direct.Test.Unit {
    // File.System.Write.Streaming.Direct is a namespace enum
    // Tests verify the namespace and nested types exist

    @Test("Direct namespace exists")
    func directNamespaceExists() {
        _ = File.System.Write.Streaming.Direct.self
        _ = File.System.Write.Streaming.Direct.Options.self
        _ = File.System.Write.Streaming.Direct.Strategy.self
    }
}
