//
//  File.System.Write.Atomic.Strategy Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Strategy {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Strategy.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Atomic.Strategy] = [.replaceExisting, .noClobber]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test("rawValue for .replaceExisting")
    func rawValueReplaceExisting() {
        #expect(File.System.Write.Atomic.Strategy.replaceExisting.rawValue == 0)
    }

    @Test("rawValue for .noClobber")
    func rawValueNoClobber() {
        #expect(File.System.Write.Atomic.Strategy.noClobber.rawValue == 1)
    }

    @Test("rawValue round-trip for .replaceExisting")
    func rawValueRoundTripReplaceExisting() {
        let strategy = File.System.Write.Atomic.Strategy.replaceExisting
        let restored = File.System.Write.Atomic.Strategy(rawValue: strategy.rawValue)
        #expect(restored == strategy)
    }

    @Test("rawValue round-trip for .noClobber")
    func rawValueRoundTripNoClobber() {
        let strategy = File.System.Write.Atomic.Strategy.noClobber
        let restored = File.System.Write.Atomic.Strategy(rawValue: strategy.rawValue)
        #expect(restored == strategy)
    }

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.System.Write.Atomic.Strategy.serialize(.replaceExisting, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.System.Write.Atomic.Strategy.serialize(.noClobber, into: &buffer)
        #expect(buffer == [1])
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Strategy.Test.EdgeCase {
    @Test("invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(File.System.Write.Atomic.Strategy(rawValue: 255) == nil)
    }

    @Test("boundary rawValue (just past valid)")
    func boundaryRawValue() {
        #expect(File.System.Write.Atomic.Strategy(rawValue: 2) == nil)
    }

    @Test("all invalid rawValues from 2 to 255 return nil")
    func allInvalidRawValues() {
        for rawValue in UInt8(2)...UInt8(255) {
            #expect(File.System.Write.Atomic.Strategy(rawValue: rawValue) == nil)
        }
    }
}
