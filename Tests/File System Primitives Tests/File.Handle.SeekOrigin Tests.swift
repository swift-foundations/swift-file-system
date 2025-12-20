//
//  File.Handle.SeekOrigin Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Handle.SeekOrigin {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Handle.SeekOrigin.Test.Unit {

    // MARK: - Case Existence

    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.Handle.SeekOrigin] = [.start, .current, .end]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    // MARK: - RawRepresentable

    @Test("rawValue for .start")
    func rawValueStart() {
        #expect(File.Handle.SeekOrigin.start.rawValue == 0)
    }

    @Test("rawValue for .current")
    func rawValueCurrent() {
        #expect(File.Handle.SeekOrigin.current.rawValue == 1)
    }

    @Test("rawValue for .end")
    func rawValueEnd() {
        #expect(File.Handle.SeekOrigin.end.rawValue == 2)
    }

    @Test("rawValue round-trip for .start")
    func rawValueRoundTripStart() {
        let origin = File.Handle.SeekOrigin.start
        let restored = File.Handle.SeekOrigin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    @Test("rawValue round-trip for .current")
    func rawValueRoundTripCurrent() {
        let origin = File.Handle.SeekOrigin.current
        let restored = File.Handle.SeekOrigin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    @Test("rawValue round-trip for .end")
    func rawValueRoundTripEnd() {
        let origin = File.Handle.SeekOrigin.end
        let restored = File.Handle.SeekOrigin(rawValue: origin.rawValue)
        #expect(restored == origin)
    }

    // MARK: - Binary.Serializable

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.Handle.SeekOrigin.serialize(.start, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.Handle.SeekOrigin.serialize(.current, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Handle.SeekOrigin.serialize(.end, into: &buffer)
        #expect(buffer == [2])
    }

    // MARK: - Sendable

    @Test("SeekOrigin is Sendable")
    func sendable() async {
        let origin: File.Handle.SeekOrigin = .current

        let result = await Task {
            origin
        }.value

        #expect(result == .current)
    }

    // MARK: - Switch Exhaustiveness

    @Test("exhaustive switch covers all cases")
    func exhaustiveSwitch() {
        let origins: [File.Handle.SeekOrigin] = [.start, .current, .end]

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

extension File.Handle.SeekOrigin.Test.EdgeCase {

    @Test("invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(File.Handle.SeekOrigin(rawValue: 255) == nil)
    }

    @Test("boundary rawValue (just past valid)")
    func boundaryRawValue() {
        #expect(File.Handle.SeekOrigin(rawValue: 3) == nil)
    }

    @Test("all invalid rawValues from 3 to 255 return nil")
    func allInvalidRawValues() {
        for rawValue in UInt8(3)...UInt8(255) {
            #expect(File.Handle.SeekOrigin(rawValue: rawValue) == nil)
        }
    }

    @Test("SeekOrigin used in collection")
    func inCollection() {
        let origins: [File.Handle.SeekOrigin] = [.start, .current, .end]
        #expect(origins.count == 3)
        #expect(origins[0] == .start)
        #expect(origins[1] == .current)
        #expect(origins[2] == .end)
    }

    @Test("SeekOrigin as dictionary key")
    func asDictionaryKey() {
        let descriptions: [File.Handle.SeekOrigin: String] = [
            .start: "beginning",
            .current: "current position",
            .end: "end of file",
        ]

        #expect(descriptions[.start] == "beginning")
        #expect(descriptions[.current] == "current position")
        #expect(descriptions[.end] == "end of file")
    }
}
