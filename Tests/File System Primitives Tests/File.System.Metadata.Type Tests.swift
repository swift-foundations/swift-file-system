//
//  File.System.Metadata.Kind Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

// Note: Cannot use #TestSuites macro due to `Type` being a Swift keyword

@Suite("File.System.Metadata.Kind Tests")
struct FileSystemMetadataTypeTests {
    @Suite("Unit")
    struct Unit {
        @Test("all cases are distinct")
        func allCasesDistinct() {
            let allCases: [File.System.Metadata.Kind] = [
                .regular, .directory, .symbolicLink, .blockDevice,
                .characterDevice, .fifo, .socket,
            ]
            let rawValues = allCases.map(\.rawValue)
            #expect(Set(rawValues).count == allCases.count)
        }

        @Test("rawValue for .regular")
        func rawValueRegular() {
            #expect(File.System.Metadata.Kind.regular.rawValue == 0)
        }

        @Test("rawValue for .directory")
        func rawValueDirectory() {
            #expect(File.System.Metadata.Kind.directory.rawValue == 1)
        }

        @Test("rawValue for .symbolicLink")
        func rawValueSymbolicLink() {
            #expect(File.System.Metadata.Kind.symbolicLink.rawValue == 2)
        }

        @Test("rawValue for .blockDevice")
        func rawValueBlockDevice() {
            #expect(File.System.Metadata.Kind.blockDevice.rawValue == 3)
        }

        @Test("rawValue for .characterDevice")
        func rawValueCharacterDevice() {
            #expect(File.System.Metadata.Kind.characterDevice.rawValue == 4)
        }

        @Test("rawValue for .fifo")
        func rawValueFifo() {
            #expect(File.System.Metadata.Kind.fifo.rawValue == 5)
        }

        @Test("rawValue for .socket")
        func rawValueSocket() {
            #expect(File.System.Metadata.Kind.socket.rawValue == 6)
        }

        @Test("rawValue round-trip for all cases")
        func rawValueRoundTripAllCases() {
            let allCases: [File.System.Metadata.Kind] = [
                .regular, .directory, .symbolicLink, .blockDevice,
                .characterDevice, .fifo, .socket,
            ]
            for type in allCases {
                let restored = File.System.Metadata.Kind(rawValue: type.rawValue)
                #expect(restored == type)
            }
        }

        @Test("Binary.Serializable - serialize produces correct bytes")
        func binarySerialize() {
            var buffer: [UInt8] = []
            File.System.Metadata.Kind.serialize(.regular, into: &buffer)
            #expect(buffer == [0])

            buffer = []
            File.System.Metadata.Kind.serialize(.directory, into: &buffer)
            #expect(buffer == [1])

            buffer = []
            File.System.Metadata.Kind.serialize(.symbolicLink, into: &buffer)
            #expect(buffer == [2])

            buffer = []
            File.System.Metadata.Kind.serialize(.blockDevice, into: &buffer)
            #expect(buffer == [3])

            buffer = []
            File.System.Metadata.Kind.serialize(.characterDevice, into: &buffer)
            #expect(buffer == [4])

            buffer = []
            File.System.Metadata.Kind.serialize(.fifo, into: &buffer)
            #expect(buffer == [5])

            buffer = []
            File.System.Metadata.Kind.serialize(.socket, into: &buffer)
            #expect(buffer == [6])
        }
    }

    @Suite("EdgeCase")
    struct EdgeCase {
        @Test("invalid rawValue returns nil")
        func invalidRawValue() {
            #expect(File.System.Metadata.Kind(rawValue: 255) == nil)
        }

        @Test("boundary rawValue (just past valid)")
        func boundaryRawValue() {
            #expect(File.System.Metadata.Kind(rawValue: 7) == nil)
        }

        @Test("all invalid rawValues from 7 to 255 return nil")
        func allInvalidRawValues() {
            for rawValue in UInt8(7)...UInt8(255) {
                #expect(File.System.Metadata.Kind(rawValue: rawValue) == nil)
            }
        }
    }
}
