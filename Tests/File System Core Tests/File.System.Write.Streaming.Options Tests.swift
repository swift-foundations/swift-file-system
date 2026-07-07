//
//  File.System.Write.Streaming.Options Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Options {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Options.Test.Unit {
    @Test
    func `default init values`() {
        let options = File.System.Write.Streaming.Options()

        // Default commit is atomic with default atomic options
        if case .atomic(let atomicOptions) = options.commit {
            #expect(atomicOptions.strategy == .replaceExisting)
            #expect(atomicOptions.durability == .full)
        } else {
            Issue.record("Expected atomic commit policy by default")
        }
    }

    @Test
    func `custom init values`() {
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .create))
        )

        if case .direct(let directOptions) = options.commit {
            #expect(directOptions.strategy == .create)
        } else {
            Issue.record("Expected direct commit policy")
        }
    }

    @Test
    func `commit property is settable`() {
        var options = File.System.Write.Streaming.Options()

        options.commit = .direct(.init())
        if case .direct = options.commit {
            // Success
        } else {
            Issue.record("Expected direct commit policy")
        }
    }

    @Test
    func `Options is Sendable`() {
        let options = File.System.Write.Streaming.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Options.Test.`Edge Case` {
    @Test
    func `atomic commit with noClobber strategy`() {
        let options = File.System.Write.Streaming.Options(
            commit: .atomic(.init(strategy: .noClobber))
        )

        if case .atomic(let atomicOptions) = options.commit {
            #expect(atomicOptions.strategy == .noClobber)
        } else {
            Issue.record("Expected atomic commit policy")
        }
    }

    @Test
    func `direct commit with truncate strategy`() {
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .truncate))
        )

        if case .direct(let directOptions) = options.commit {
            #expect(directOptions.strategy == .truncate)
        } else {
            Issue.record("Expected direct commit policy")
        }
    }

    @Test
    func `all durability levels with direct commit`() {
        let full = File.System.Write.Streaming.Options(
            commit: .direct(.init(durability: .full))
        )
        let dataOnly = File.System.Write.Streaming.Options(
            commit: .direct(.init(durability: .dataOnly))
        )
        let none = File.System.Write.Streaming.Options(
            commit: .direct(.init(durability: .none))
        )

        if case .direct(let o) = full.commit {
            #expect(o.durability == .full)
        }
        if case .direct(let o) = dataOnly.commit {
            #expect(o.durability == .dataOnly)
        }
        if case .direct(let o) = none.commit {
            #expect(o.durability == .none)
        }
    }
}
