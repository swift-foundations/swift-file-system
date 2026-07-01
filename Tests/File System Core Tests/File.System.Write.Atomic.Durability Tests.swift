//
//  File.System.Write.Durability Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Durability {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Durability.Test.Unit {
    @Test
    func `all cases are distinct`() {
        let allCases: [File.System.Write.Durability] = [.full, .dataOnly, .none]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test
    func `.full case`() {
        let durability: File.System.Write.Durability = .full
        if case .full = durability {
            // Success
        } else {
            Issue.record("Expected full case")
        }
    }

    @Test
    func `.dataOnly case`() {
        let durability: File.System.Write.Durability = .dataOnly
        if case .dataOnly = durability {
            // Success
        } else {
            Issue.record("Expected dataOnly case")
        }
    }

    @Test
    func `.none case`() {
        let durability: File.System.Write.Durability = .none
        if case .none = durability {
            // Success
        } else {
            Issue.record("Expected none case")
        }
    }

    @Test
    func `Equatable conformance`() {
        #expect(File.System.Write.Durability.full == .full)
        #expect(File.System.Write.Durability.dataOnly == .dataOnly)
        #expect(File.System.Write.Durability.none == .none)
        #expect(File.System.Write.Durability.full != .dataOnly)
        #expect(File.System.Write.Durability.full != .none)
        #expect(File.System.Write.Durability.dataOnly != .none)
    }

    @Test
    func `Durability is Sendable`() {
        let durability = File.System.Write.Durability.full
        Task {
            _ = durability
        }
    }

    @Test
    func `rawValue for .full`() {
        #expect(File.System.Write.Durability.full.rawValue == 0)
    }

    @Test
    func `rawValue for .dataOnly`() {
        #expect(File.System.Write.Durability.dataOnly.rawValue == 1)
    }

    @Test
    func `rawValue for .none`() {
        #expect(File.System.Write.Durability.none.rawValue == 2)
    }

    @Test
    func `rawValue round-trip for .full`() {
        let durability = File.System.Write.Durability.full
        let restored = File.System.Write.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

    @Test
    func `rawValue round-trip for .dataOnly`() {
        let durability = File.System.Write.Durability.dataOnly
        let restored = File.System.Write.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

    @Test
    func `rawValue round-trip for .none`() {
        let durability = File.System.Write.Durability.none
        let restored = File.System.Write.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

}

// MARK: - Edge Cases

extension File.System.Write.Durability.Test.EdgeCase {
    @Test
    func `Hashable conformance`() {
        let set: Set<File.System.Write.Durability> = [.full, .dataOnly, .none]
        #expect(set.count == 3)
        #expect(set.contains(.full))
        #expect(set.contains(.dataOnly))
        #expect(set.contains(.none))
    }

    @Test
    func `invalid rawValue returns nil`() {
        #expect(File.System.Write.Durability(rawValue: 255) == nil)
    }

    @Test
    func `boundary rawValue (just past valid)`() {
        #expect(File.System.Write.Durability(rawValue: 3) == nil)
    }

    @Test
    func `all invalid rawValues from 3 to 255 return nil`() {
        for rawValue in UInt8(3)...UInt8(255) {
            #expect(File.System.Write.Durability(rawValue: rawValue) == nil)
        }
    }
}
