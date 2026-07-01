//
//  File.System.Write.Streaming.Commit.Policy Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Commit.Policy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Commit.Policy.Test.Unit {
    @Test
    func `.atomic case with default options`() {
        let policy: File.System.Write.Streaming.Commit.Policy = .atomic()

        if case .atomic(let options) = policy {
            #expect(options.strategy == .replaceExisting)
            #expect(options.durability == .full)
        } else {
            Issue.record("Expected atomic case")
        }
    }

    @Test
    func `.atomic case with custom options`() {
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

    @Test
    func `.direct case with default options`() {
        let policy: File.System.Write.Streaming.Commit.Policy = .direct()

        if case .direct(let options) = policy {
            #expect(options.strategy == .truncate)
            #expect(options.durability == .full)
        } else {
            Issue.record("Expected direct case")
        }
    }

    @Test
    func `.direct case with custom options`() {
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

    @Test
    func `Policy is Sendable`() {
        let policy = File.System.Write.Streaming.Commit.Policy.atomic()
        Task {
            _ = policy
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Commit.Policy.Test.EdgeCase {
    @Test
    func `atomic with none durability`() {
        let options = File.System.Write.Streaming.Atomic.Options(durability: .none)
        let policy: File.System.Write.Streaming.Commit.Policy = .atomic(options)

        if case .atomic(let o) = policy {
            #expect(o.durability == .none)
        } else {
            Issue.record("Expected atomic case")
        }
    }

    @Test
    func `direct with create strategy`() {
        let options = File.System.Write.Streaming.Direct.Options(strategy: .create)
        let policy: File.System.Write.Streaming.Commit.Policy = .direct(options)

        if case .direct(let o) = policy {
            #expect(o.strategy == .create)
        } else {
            Issue.record("Expected direct case")
        }
    }
}
