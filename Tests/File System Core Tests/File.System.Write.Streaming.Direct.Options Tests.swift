//
//  File.System.Write.Streaming.Direct.Options Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Direct.Options {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Direct.Options.Test.Unit {
    @Test
    func `default init values`() {
        let options = File.System.Write.Streaming.Direct.Options()

        #expect(options.strategy == .truncate)
        #expect(options.durability == .full)
    }

    @Test
    func `custom init values`() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .dataOnly
        )

        #expect(options.strategy == .create)
        #expect(options.durability == .dataOnly)
    }

    @Test
    func `strategy property is settable`() {
        var options = File.System.Write.Streaming.Direct.Options()
        #expect(options.strategy == .truncate)

        options.strategy = .create
        #expect(options.strategy == .create)
    }

    @Test
    func `durability property is settable`() {
        var options = File.System.Write.Streaming.Direct.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test
    func `Options is Sendable`() {
        let options = File.System.Write.Streaming.Direct.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Direct.Options.Test.`Edge Case` {
    @Test
    func `create with none durability`() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .none
        )

        #expect(options.strategy == .create)
        #expect(options.durability == .none)
    }

    @Test
    func `all durability levels with truncate`() {
        let full = File.System.Write.Streaming.Direct.Options(durability: .full)
        let dataOnly = File.System.Write.Streaming.Direct.Options(durability: .dataOnly)
        let none = File.System.Write.Streaming.Direct.Options(durability: .none)

        #expect(full.durability == .full)
        #expect(dataOnly.durability == .dataOnly)
        #expect(none.durability == .none)
    }
}
