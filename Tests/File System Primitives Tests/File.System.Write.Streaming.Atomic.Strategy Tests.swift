//
//  File.System.Write.Streaming.Atomic.Strategy Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Atomic.Strategy {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Strategy.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Streaming.Atomic.Strategy] = [
            .replaceExisting, .noClobber
        ]
        #expect(allCases.count == 2)
        #expect(allCases[0] != allCases[1])
    }

    @Test(".replaceExisting case")
    func replaceExistingCase() {
        let strategy: File.System.Write.Streaming.Atomic.Strategy = .replaceExisting
        if case .replaceExisting = strategy {
            // Success
        } else {
            Issue.record("Expected replaceExisting case")
        }
    }

    @Test(".noClobber case")
    func noClobberCase() {
        let strategy: File.System.Write.Streaming.Atomic.Strategy = .noClobber
        if case .noClobber = strategy {
            // Success
        } else {
            Issue.record("Expected noClobber case")
        }
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(File.System.Write.Streaming.Atomic.Strategy.replaceExisting == .replaceExisting)
        #expect(File.System.Write.Streaming.Atomic.Strategy.noClobber == .noClobber)
        #expect(File.System.Write.Streaming.Atomic.Strategy.replaceExisting != .noClobber)
    }

    @Test("Strategy is Sendable")
    func strategyIsSendable() {
        let strategy = File.System.Write.Streaming.Atomic.Strategy.replaceExisting
        Task {
            _ = strategy
        }
    }
}
