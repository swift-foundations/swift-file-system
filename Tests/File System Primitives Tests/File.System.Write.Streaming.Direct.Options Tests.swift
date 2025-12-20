//
//  File.System.Write.Streaming.Direct.Options Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Direct.Options {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Direct.Options.Test.Unit {
    @Test("default init values")
    func defaultInitValues() {
        let options = File.System.Write.Streaming.Direct.Options()

        #expect(options.strategy == .truncate)
        #expect(options.durability == .full)
    }

    @Test("custom init values")
    func customInitValues() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .dataOnly
        )

        #expect(options.strategy == .create)
        #expect(options.durability == .dataOnly)
    }

    @Test("strategy property is settable")
    func strategyPropertySettable() {
        var options = File.System.Write.Streaming.Direct.Options()
        #expect(options.strategy == .truncate)

        options.strategy = .create
        #expect(options.strategy == .create)
    }

    @Test("durability property is settable")
    func durabilityPropertySettable() {
        var options = File.System.Write.Streaming.Direct.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options = File.System.Write.Streaming.Direct.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Direct.Options.Test.EdgeCase {
    @Test("create with none durability")
    func createWithNoneDurability() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .none
        )

        #expect(options.strategy == .create)
        #expect(options.durability == .none)
    }

    @Test("all durability levels with truncate")
    func allDurabilityLevels() {
        let full = File.System.Write.Streaming.Direct.Options(durability: .full)
        let dataOnly = File.System.Write.Streaming.Direct.Options(durability: .dataOnly)
        let none = File.System.Write.Streaming.Direct.Options(durability: .none)

        #expect(full.durability == .full)
        #expect(dataOnly.durability == .dataOnly)
        #expect(none.durability == .none)
    }
}
