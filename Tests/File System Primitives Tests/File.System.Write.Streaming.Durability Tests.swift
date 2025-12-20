//
//  File.System.Write.Streaming.Durability Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Durability {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Durability.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Streaming.Durability] = [
            .full, .dataOnly, .none
        ]
        #expect(allCases.count == 3)
        #expect(Set([allCases[0], allCases[1], allCases[2]]).count == 3)
    }

    @Test(".full case")
    func fullCase() {
        let durability: File.System.Write.Streaming.Durability = .full
        if case .full = durability {
            // Success
        } else {
            Issue.record("Expected full case")
        }
    }

    @Test(".dataOnly case")
    func dataOnlyCase() {
        let durability: File.System.Write.Streaming.Durability = .dataOnly
        if case .dataOnly = durability {
            // Success
        } else {
            Issue.record("Expected dataOnly case")
        }
    }

    @Test(".none case")
    func noneCase() {
        let durability: File.System.Write.Streaming.Durability = .none
        if case .none = durability {
            // Success
        } else {
            Issue.record("Expected none case")
        }
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(File.System.Write.Streaming.Durability.full == .full)
        #expect(File.System.Write.Streaming.Durability.dataOnly == .dataOnly)
        #expect(File.System.Write.Streaming.Durability.none == .none)
        #expect(File.System.Write.Streaming.Durability.full != .dataOnly)
        #expect(File.System.Write.Streaming.Durability.full != .none)
        #expect(File.System.Write.Streaming.Durability.dataOnly != .none)
    }

    @Test("Durability is Sendable")
    func durabilityIsSendable() {
        let durability = File.System.Write.Streaming.Durability.full
        Task {
            _ = durability
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Durability.Test.EdgeCase {
    @Test("Hashable conformance")
    func hashableConformance() {
        let set: Set<File.System.Write.Streaming.Durability> = [.full, .dataOnly, .none]
        #expect(set.count == 3)
        #expect(set.contains(.full))
        #expect(set.contains(.dataOnly))
        #expect(set.contains(.none))
    }
}
