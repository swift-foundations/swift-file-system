//
//  File.System.Write.Streaming.Atomic.Options Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Atomic.Options {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Options.Test.Unit {
    @Test
    func `default init values`() {
        let options = File.System.Write.Streaming.Atomic.Options()

        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
    }

    @Test
    func `custom init values`() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
    }

    @Test
    func `strategy property is settable`() {
        var options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.strategy == .replaceExisting)

        options.strategy = .noClobber
        #expect(options.strategy == .noClobber)
    }

    @Test
    func `durability property is settable`() {
        var options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test
    func `Options is Sendable`() {
        let options = File.System.Write.Streaming.Atomic.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Atomic.Options.Test.`Edge Case` {
    @Test
    func `noClobber with none durability`() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .none
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .none)
    }

    @Test
    func `all durability levels with replaceExisting`() {
        let full = File.System.Write.Streaming.Atomic.Options(durability: .full)
        let dataOnly = File.System.Write.Streaming.Atomic.Options(durability: .dataOnly)
        let none = File.System.Write.Streaming.Atomic.Options(durability: .none)

        #expect(full.durability == .full)
        #expect(dataOnly.durability == .dataOnly)
        #expect(none.durability == .none)
    }
}
