//
//  File.System.Write.Streaming.Options Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Options {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Options.Test.Unit {
    @Test("default init values")
    func defaultInitValues() {
        let options = File.System.Write.Streaming.Options()

        // Default commit is atomic with default atomic options
        if case .atomic(let atomicOptions) = options.commit {
            #expect(atomicOptions.strategy == .replaceExisting)
            #expect(atomicOptions.durability == .full)
        } else {
            Issue.record("Expected atomic commit policy by default")
        }

        #expect(options.createIntermediates == false)
    }

    @Test("custom init values")
    func customInitValues() {
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .create)),
            createIntermediates: true
        )

        if case .direct(let directOptions) = options.commit {
            #expect(directOptions.strategy == .create)
        } else {
            Issue.record("Expected direct commit policy")
        }

        #expect(options.createIntermediates == true)
    }

    @Test("commit property is settable")
    func commitPropertySettable() {
        var options = File.System.Write.Streaming.Options()

        options.commit = .direct(.init())
        if case .direct = options.commit {
            // Success
        } else {
            Issue.record("Expected direct commit policy")
        }
    }

    @Test("createIntermediates property is settable")
    func createIntermediatesPropertySettable() {
        var options = File.System.Write.Streaming.Options()
        #expect(options.createIntermediates == false)

        options.createIntermediates = true
        #expect(options.createIntermediates == true)
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options = File.System.Write.Streaming.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Options.Test.EdgeCase {
    @Test("atomic commit with noClobber strategy")
    func atomicCommitWithNoClobber() {
        let options = File.System.Write.Streaming.Options(
            commit: .atomic(.init(strategy: .noClobber))
        )

        if case .atomic(let atomicOptions) = options.commit {
            #expect(atomicOptions.strategy == .noClobber)
        } else {
            Issue.record("Expected atomic commit policy")
        }
    }

    @Test("direct commit with truncate strategy")
    func directCommitWithTruncate() {
        let options = File.System.Write.Streaming.Options(
            commit: .direct(.init(strategy: .truncate))
        )

        if case .direct(let directOptions) = options.commit {
            #expect(directOptions.strategy == .truncate)
        } else {
            Issue.record("Expected direct commit policy")
        }
    }

    @Test("createIntermediates with atomic commit")
    func createIntermediatesWithAtomic() {
        let options = File.System.Write.Streaming.Options(
            commit: .atomic(.init()),
            createIntermediates: true
        )

        if case .atomic = options.commit {
            #expect(options.createIntermediates == true)
        } else {
            Issue.record("Expected atomic commit policy")
        }
    }

    @Test("all durability levels with direct commit")
    func allDurabilityLevelsWithDirect() {
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
