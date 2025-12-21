//
//  File.Handle.Seek.Origin Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Handle.Seek.Origin {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Handle.Seek.Origin.Test.Unit {

    // MARK: - Case Existence

    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.Handle.Seek.Origin] = [.start, .current, .end]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    // MARK: - RawRepresentable

    @Test("rawValue for .start")
    func rawValueStart() {
        #expect(File.Handle.Seek.Origin.start.rawValue == 0)
    }

    @Test("rawValue for .current")
    func rawValueCurrent() {
        #expect(File.Handle.Seek.Origin.current.rawValue == 1)
    }

    @Test("rawValue for .end")
    func rawValueEnd() {
        #expect(File.Handle.Seek.Origin.end.rawValue == 2)
    }

    @Test("rawValue round-trip for .start")
    func rawValueRoundTripStart() {
        let origin = File.Handle.Seek.Origin.start
        let restored = File.Handle.Seek.Origin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    @Test("rawValue round-trip for .current")
    func rawValueRoundTripCurrent() {
        let origin = File.Handle.Seek.Origin.current
        let restored = File.Handle.Seek.Origin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    @Test("rawValue round-trip for .end")
    func rawValueRoundTripEnd() {
        let origin = File.Handle.Seek.Origin.end
        let restored = File.Handle.Seek.Origin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    // MARK: - Binary.Serializable

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.Handle.Seek.Origin.serialize(.start, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.Handle.Seek.Origin.serialize(.current, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Handle.Seek.Origin.serialize(.end, into: &buffer)
        #expect(buffer == [2])
    }

    // MARK: - Sendable

    @Test("Seek.Origin is Sendable")
    func sendable() async {
        let origin: File.Handle.Seek.Origin = .current

        let result = await Task {
            origin
        }.value

        #expect(result == .current)
    }

    // MARK: - Switch Exhaustiveness

    @Test("exhaustive switch covers all cases")
    func exhaustiveSwitch() {
        let origins: [File.Handle.Seek.Origin] = [.start, .current, .end]

        for origin in origins {
            switch origin {
            case .start:
                #expect(origin.rawValue == 0)
            case .current:
                #expect(origin.rawValue == 1)
            case .end:
                #expect(origin.rawValue == 2)
            }
        }
    }
}

// MARK: - Edge Cases

extension File.Handle.Seek.Origin.Test.EdgeCase {

    @Test("invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(File.Handle.Seek.Origin(rawValue: 255) == nil)
    }

    @Test("boundary rawValue (just past valid)")
    func boundaryRawValue() {
        #expect(File.Handle.Seek.Origin(rawValue: 3) == nil)
    }

    @Test("all invalid rawValues from 3 to 255 return nil")
    func allInvalidRawValues() {
        for rawValue in UInt8(3)...UInt8(255) {
            #expect(File.Handle.Seek.Origin(rawValue: rawValue) == nil)
        }
    }

    @Test("Seek.Origin used in collection")
    func inCollection() {
        let origins: [File.Handle.Seek.Origin] = [.start, .current, .end]
        #expect(origins.count == 3)
        #expect(origins[0] == .start)
        #expect(origins[1] == .current)
        #expect(origins[2] == .end)
    }

    @Test("Seek.Origin as dictionary key")
    func asDictionaryKey() {
        let descriptions: [File.Handle.Seek.Origin: String] = [
            .start: "beginning",
            .current: "current position",
            .end: "end of file",
        ]

        #expect(descriptions[.start] == "beginning")
        #expect(descriptions[.current] == "current position")
        #expect(descriptions[.end] == "end of file")
    }
}
