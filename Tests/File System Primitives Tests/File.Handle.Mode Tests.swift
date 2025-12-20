//
//  File.Handle.Mode Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Handle.Mode {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Handle.Mode.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.Handle.Mode] = [.read, .write, .readWrite, .append]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test("rawValue for .read")
    func rawValueRead() {
        #expect(File.Handle.Mode.read.rawValue == 0)
    }

    @Test("rawValue for .write")
    func rawValueWrite() {
        #expect(File.Handle.Mode.write.rawValue == 1)
    }

    @Test("rawValue for .readWrite")
    func rawValueReadWrite() {
        #expect(File.Handle.Mode.readWrite.rawValue == 2)
    }

    @Test("rawValue for .append")
    func rawValueAppend() {
        #expect(File.Handle.Mode.append.rawValue == 3)
    }

    @Test("rawValue round-trip for .read")
    func rawValueRoundTripRead() {
        let mode = File.Handle.Mode.read
        let restored = File.Handle.Mode(rawValue: mode.rawValue)
        #expect(restored == mode)
    }

    @Test("rawValue round-trip for .write")
    func rawValueRoundTripWrite() {
        let mode = File.Handle.Mode.write
        let restored = File.Handle.Mode(rawValue: mode.rawValue)
        #expect(restored == mode)
    }

    @Test("rawValue round-trip for .readWrite")
    func rawValueRoundTripReadWrite() {
        let mode = File.Handle.Mode.readWrite
        let restored = File.Handle.Mode(rawValue: mode.rawValue)
        #expect(restored == mode)
    }

    @Test("rawValue round-trip for .append")
    func rawValueRoundTripAppend() {
        let mode = File.Handle.Mode.append
        let restored = File.Handle.Mode(rawValue: mode.rawValue)
        #expect(restored == mode)
    }

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.Handle.Mode.serialize(.read, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.Handle.Mode.serialize(.write, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Handle.Mode.serialize(.readWrite, into: &buffer)
        #expect(buffer == [2])

        buffer = []
        File.Handle.Mode.serialize(.append, into: &buffer)
        #expect(buffer == [3])
    }
}

// MARK: - Edge Cases

extension File.Handle.Mode.Test.EdgeCase {
    @Test("invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(File.Handle.Mode(rawValue: 255) == nil)
    }

    @Test("boundary rawValue (just past valid)")
    func boundaryRawValue() {
        #expect(File.Handle.Mode(rawValue: 4) == nil)
    }

    @Test("all invalid rawValues from 4 to 255 return nil")
    func allInvalidRawValues() {
        for rawValue in UInt8(4)...UInt8(255) {
            #expect(File.Handle.Mode(rawValue: rawValue) == nil)
        }
    }
}
