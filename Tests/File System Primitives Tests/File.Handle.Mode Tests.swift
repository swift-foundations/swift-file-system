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
    @Test("individual options are distinct")
    func optionsDistinct() {
        let read = File.Handle.Mode.read
        let write = File.Handle.Mode.write
        let append = File.Handle.Mode.append

        #expect(read != write)
        #expect(write != append)
        #expect(read != append)
    }

    @Test("rawValue for .read")
    func rawValueRead() {
        #expect(File.Handle.Mode.read.rawValue == 1)
    }

    @Test("rawValue for .write")
    func rawValueWrite() {
        #expect(File.Handle.Mode.write.rawValue == 2)
    }

    @Test("rawValue for .append")
    func rawValueAppend() {
        #expect(File.Handle.Mode.append.rawValue == 4)
    }

    @Test("rawValue for combined [.read, .write]")
    func rawValueReadWrite() {
        let mode: File.Handle.Mode = [.read, .write]
        #expect(mode.rawValue == 3)
    }

    @Test("rawValue for combined [.read, .append]")
    func rawValueReadAppend() {
        let mode: File.Handle.Mode = [.read, .append]
        #expect(mode.rawValue == 5)
    }

    @Test("contains checks")
    func containsChecks() {
        let readWrite: File.Handle.Mode = [.read, .write]
        #expect(readWrite.contains(.read))
        #expect(readWrite.contains(.write))
        #expect(!readWrite.contains(.append))

        let readAppend: File.Handle.Mode = [.read, .append]
        #expect(readAppend.contains(.read))
        #expect(!readAppend.contains(.write))
        #expect(readAppend.contains(.append))
    }

    @Test("empty mode")
    func emptyMode() {
        let empty: File.Handle.Mode = []
        #expect(empty.rawValue == 0)
        #expect(empty.isEmpty)
    }

    @Test("Binary.Serializable - serialize produces correct byte")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.Handle.Mode.serialize(.read, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Handle.Mode.serialize(.write, into: &buffer)
        #expect(buffer == [2])

        buffer = []
        File.Handle.Mode.serialize([.read, .write], into: &buffer)
        #expect(buffer == [3])

        buffer = []
        File.Handle.Mode.serialize(.append, into: &buffer)
        #expect(buffer == [4])
    }
}

// MARK: - Edge Cases

extension File.Handle.Mode.Test.EdgeCase {
    @Test("OptionSet allows any combination")
    func optionSetCombinations() {
        // All valid combinations
        let readOnly: File.Handle.Mode = .read
        let writeOnly: File.Handle.Mode = .write
        let appendOnly: File.Handle.Mode = .append
        let readWrite: File.Handle.Mode = [.read, .write]
        let readAppend: File.Handle.Mode = [.read, .append]
        let writeAppend: File.Handle.Mode = [.write, .append]
        let all: File.Handle.Mode = [.read, .write, .append]

        #expect(readOnly.rawValue == 1)
        #expect(writeOnly.rawValue == 2)
        #expect(appendOnly.rawValue == 4)
        #expect(readWrite.rawValue == 3)
        #expect(readAppend.rawValue == 5)
        #expect(writeAppend.rawValue == 6)
        #expect(all.rawValue == 7)
    }

    @Test("mode is Sendable")
    func modeSendable() async {
        let mode: File.Handle.Mode = [.read, .write]

        let result = await Task {
            mode
        }.value

        #expect(result == [.read, .write])
    }
}
