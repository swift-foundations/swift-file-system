//
//  File.Directory.Entry.Kind Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

// Note: Cannot use #TestSuites macro due to `Type` being a Swift keyword

@Suite("File.Directory.Entry.Kind Tests")
struct FileDirectoryEntryTypeTests {
    @Suite("Unit")
    struct Unit {
        @Test("all cases are distinct")
        func allCasesDistinct() {
            let allCases: [File.Directory.Entry.Kind] = [.file, .directory, .symbolicLink, .other]
            let rawValues = allCases.map(\.rawValue)
            #expect(Set(rawValues).count == allCases.count)
        }

        @Test("rawValue for .file")
        func rawValueFile() {
            #expect(File.Directory.Entry.Kind.file.rawValue == 0)
        }

        @Test("rawValue for .directory")
        func rawValueDirectory() {
            #expect(File.Directory.Entry.Kind.directory.rawValue == 1)
        }

        @Test("rawValue for .symbolicLink")
        func rawValueSymbolicLink() {
            #expect(File.Directory.Entry.Kind.symbolicLink.rawValue == 2)
        }

        @Test("rawValue for .other")
        func rawValueOther() {
            #expect(File.Directory.Entry.Kind.other.rawValue == 3)
        }

        @Test("rawValue round-trip for .file")
        func rawValueRoundTripFile() {
            let type = File.Directory.Entry.Kind.file
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test("rawValue round-trip for .directory")
        func rawValueRoundTripDirectory() {
            let type = File.Directory.Entry.Kind.directory
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test("rawValue round-trip for .symbolicLink")
        func rawValueRoundTripSymbolicLink() {
            let type = File.Directory.Entry.Kind.symbolicLink
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test("rawValue round-trip for .other")
        func rawValueRoundTripOther() {
            let type = File.Directory.Entry.Kind.other
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test("Binary.Serializable - serialize produces correct byte")
        func binarySerialize() {
            var buffer: [UInt8] = []
            File.Directory.Entry.Kind.serialize(.file, into: &buffer)
            #expect(buffer == [0])

            buffer = []
            File.Directory.Entry.Kind.serialize(.directory, into: &buffer)
            #expect(buffer == [1])

            buffer = []
            File.Directory.Entry.Kind.serialize(.symbolicLink, into: &buffer)
            #expect(buffer == [2])

            buffer = []
            File.Directory.Entry.Kind.serialize(.other, into: &buffer)
            #expect(buffer == [3])
        }
    }

    @Suite("EdgeCase")
    struct EdgeCase {
        @Test("invalid rawValue returns nil")
        func invalidRawValue() {
            #expect(File.Directory.Entry.Kind(rawValue: 255) == nil)
        }

        @Test("boundary rawValue (just past valid)")
        func boundaryRawValue() {
            #expect(File.Directory.Entry.Kind(rawValue: 4) == nil)
        }

        @Test("all invalid rawValues from 4 to 255 return nil")
        func allInvalidRawValues() {
            for rawValue in UInt8(4)...UInt8(255) {
                #expect(File.Directory.Entry.Kind(rawValue: rawValue) == nil)
            }
        }
    }
}
