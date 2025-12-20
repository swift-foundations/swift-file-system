//
//  File.System.Write.Streaming.Commit.Policy Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Commit.Policy {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Commit.Policy.Test.Unit {
    @Test(".atomic case with default options")
    func atomicCaseDefault() {
        let policy: File.System.Write.Streaming.Commit.Policy = .atomic()

        if case .atomic(let options) = policy {
            #expect(options.strategy == .replaceExisting)
            #expect(options.durability == .full)
        } else {
            Issue.record("Expected atomic case")
        }
    }

    @Test(".atomic case with custom options")
    func atomicCaseCustom() {
        let customOptions = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly
        )
        let policy: File.System.Write.Streaming.Commit.Policy = .atomic(customOptions)

        if case .atomic(let options) = policy {
            #expect(options.strategy == .noClobber)
            #expect(options.durability == .dataOnly)
        } else {
            Issue.record("Expected atomic case")
        }
    }

    @Test(".direct case with default options")
    func directCaseDefault() {
        let policy: File.System.Write.Streaming.Commit.Policy = .direct()

        if case .direct(let options) = policy {
            #expect(options.strategy == .truncate)
            #expect(options.durability == .full)
        } else {
            Issue.record("Expected direct case")
        }
    }

    @Test(".direct case with custom options")
    func directCaseCustom() {
        let customOptions = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .none
        )
        let policy: File.System.Write.Streaming.Commit.Policy = .direct(customOptions)

        if case .direct(let options) = policy {
            #expect(options.strategy == .create)
            #expect(options.durability == .none)
        } else {
            Issue.record("Expected direct case")
        }
    }

    @Test("Policy is Sendable")
    func policyIsSendable() {
        let policy = File.System.Write.Streaming.Commit.Policy.atomic()
        Task {
            _ = policy
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Commit.Policy.Test.EdgeCase {
    @Test("atomic with none durability")
    func atomicWithNoneDurability() {
        let options = File.System.Write.Streaming.Atomic.Options(durability: .none)
        let policy: File.System.Write.Streaming.Commit.Policy = .atomic(options)

        if case .atomic(let o) = policy {
            #expect(o.durability == .none)
        } else {
            Issue.record("Expected atomic case")
        }
    }

    @Test("direct with create strategy")
    func directWithCreateStrategy() {
        let options = File.System.Write.Streaming.Direct.Options(strategy: .create)
        let policy: File.System.Write.Streaming.Commit.Policy = .direct(options)

        if case .direct(let o) = policy {
            #expect(o.strategy == .create)
        } else {
            Issue.record("Expected direct case")
        }
    }
}
