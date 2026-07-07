//
//  File.System.Write.Atomic.Options Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Atomic.Options {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Options.Test.Unit {
    @Test
    func `default init values`() {
        let options = File.System.Write.Atomic.Options()

        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
        #expect(options.preservation == .permissions)
        #expect(options.ownership == .ignore)
    }

    @Test
    func `custom init values`() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly,
            preservation: [.timestamps, .extendedAttributes, .acls],
            ownership: .preserve(strict: true)
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
        #expect(!options.preservation.contains(.permissions))
        #expect(options.preservation.contains(.timestamps))
        #expect(options.preservation.contains(.extendedAttributes))
        #expect(options.preservation.contains(.acls))
        #expect(options.ownership == .preserve(strict: true))
    }

    @Test
    func `strategy property is settable`() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.strategy == .replaceExisting)

        options.strategy = .noClobber
        #expect(options.strategy == .noClobber)
    }

    @Test
    func `durability property is settable`() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test
    func `preservation property is settable`() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.preservation.contains(.permissions))

        options.preservation = []
        #expect(options.preservation.isEmpty)

        options.preservation = .all
        #expect(options.preservation.contains(.permissions))
        #expect(options.preservation.contains(.timestamps))
        #expect(options.preservation.contains(.extendedAttributes))
        #expect(options.preservation.contains(.acls))
    }

    @Test
    func `Options is Sendable`() {
        let options = File.System.Write.Atomic.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Options.Test.`Edge Case` {
    @Test
    func `all preservation enabled with strict ownership`() {
        let options = File.System.Write.Atomic.Options(
            preservation: .all,
            ownership: .preserve(strict: true)
        )

        #expect(options.preservation.contains(.permissions))
        #expect(options.preservation.contains(.timestamps))
        #expect(options.preservation.contains(.extendedAttributes))
        #expect(options.preservation.contains(.acls))
        #expect(options.ownership == .preserve(strict: true))
    }

    @Test
    func `no preservation with ignored ownership`() {
        let options = File.System.Write.Atomic.Options(
            preservation: [],
            ownership: .ignore
        )

        #expect(options.preservation.isEmpty)
        #expect(options.ownership == .ignore)
    }

    @Test
    func `durability none with noClobber`() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            durability: .none
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .none)
    }
}
