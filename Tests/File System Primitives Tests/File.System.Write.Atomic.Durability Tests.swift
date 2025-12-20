//
//  File.System.Write.Atomic.Durability Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Durability {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Durability.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Atomic.Durability] = [.full, .dataOnly, .none]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test("rawValue for .full")
    func rawValueFull() {
        #expect(File.System.Write.Atomic.Durability.full.rawValue == 0)
    }

    @Test("rawValue for .dataOnly")
    func rawValueDataOnly() {
        #expect(File.System.Write.Atomic.Durability.dataOnly.rawValue == 1)
    }

    @Test("rawValue for .none")
    func rawValueNone() {
        #expect(File.System.Write.Atomic.Durability.none.rawValue == 2)
    }

    @Test("rawValue round-trip for .full")
    func rawValueRoundTripFull() {
        let durability = File.System.Write.Atomic.Durability.full
        let restored = File.System.Write.Atomic.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

    @Test("rawValue round-trip for .dataOnly")
    func rawValueRoundTripDataOnly() {
        let durability = File.System.Write.Atomic.Durability.dataOnly
        let restored = File.System.Write.Atomic.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

    @Test("rawValue round-trip for .none")
    func rawValueRoundTripNone() {
        let durability = File.System.Write.Atomic.Durability.none
        let restored = File.System.Write.Atomic.Durability(rawValue: durability.rawValue)
        #expect(restored == durability)
    }

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.System.Write.Atomic.Durability.serialize(.full, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.System.Write.Atomic.Durability.serialize(.dataOnly, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.System.Write.Atomic.Durability.serialize(.none, into: &buffer)
        #expect(buffer == [2])
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Durability.Test.EdgeCase {
    @Test("invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(File.System.Write.Atomic.Durability(rawValue: 255) == nil)
    }

    @Test("boundary rawValue (just past valid)")
    func boundaryRawValue() {
        #expect(File.System.Write.Atomic.Durability(rawValue: 3) == nil)
    }

    @Test("all invalid rawValues from 3 to 255 return nil")
    func allInvalidRawValues() {
        for rawValue in UInt8(3)...UInt8(255) {
            #expect(File.System.Write.Atomic.Durability(rawValue: rawValue) == nil)
        }
    }
}
