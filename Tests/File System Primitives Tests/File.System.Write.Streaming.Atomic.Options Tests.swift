//
//  File.System.Write.Streaming.Atomic.Options Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Atomic.Options {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Options.Test.Unit {
    @Test("default init values")
    func defaultInitValues() {
        let options = File.System.Write.Streaming.Atomic.Options()

        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
    }

    @Test("custom init values")
    func customInitValues() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
    }

    @Test("strategy property is settable")
    func strategyPropertySettable() {
        var options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.strategy == .replaceExisting)

        options.strategy = .noClobber
        #expect(options.strategy == .noClobber)
    }

    @Test("durability property is settable")
    func durabilityPropertySettable() {
        var options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options = File.System.Write.Streaming.Atomic.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Atomic.Options.Test.EdgeCase {
    @Test("noClobber with none durability")
    func noClobberWithNoneDurability() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .none
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .none)
    }

    @Test("all durability levels with replaceExisting")
    func allDurabilityLevels() {
        let full = File.System.Write.Streaming.Atomic.Options(durability: .full)
        let dataOnly = File.System.Write.Streaming.Atomic.Options(durability: .dataOnly)
        let none = File.System.Write.Streaming.Atomic.Options(durability: .none)

        #expect(full.durability == .full)
        #expect(dataOnly.durability == .dataOnly)
        #expect(none.durability == .none)
    }
}
