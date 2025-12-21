//
//  File.System.Write.Streaming.Direct.Strategy Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Direct.Strategy {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Direct.Strategy.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Streaming.Direct.Strategy] = [
            .create, .truncate,
        ]
        #expect(allCases.count == 2)
        #expect(allCases[0] != allCases[1])
    }

    @Test(".create case")
    func createCase() {
        let strategy: File.System.Write.Streaming.Direct.Strategy = .create
        if case .create = strategy {
            // Success
        } else {
            Issue.record("Expected create case")
        }
    }

    @Test(".truncate case")
    func truncateCase() {
        let strategy: File.System.Write.Streaming.Direct.Strategy = .truncate
        if case .truncate = strategy {
            // Success
        } else {
            Issue.record("Expected truncate case")
        }
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(File.System.Write.Streaming.Direct.Strategy.create == .create)
        #expect(File.System.Write.Streaming.Direct.Strategy.truncate == .truncate)
        #expect(File.System.Write.Streaming.Direct.Strategy.create != .truncate)
    }

    @Test("Strategy is Sendable")
    func strategyIsSendable() {
        let strategy = File.System.Write.Streaming.Direct.Strategy.create
        Task {
            _ = strategy
        }
    }
}
