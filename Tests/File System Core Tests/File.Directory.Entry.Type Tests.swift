//
//  File.Directory.Entry.Kind Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

// Note: Cannot use #Tests macro due to `Type` being a Swift keyword

@Suite
struct `File.Directory.Entry.Kind Tests` {
    @Suite
    struct `Unit` {
        @Test
        func `all cases are distinct`() {
            let allCases: [File.Directory.Entry.Kind] = [.file, .directory, .symbolicLink, .other]
            let rawValues = allCases.map(\.rawValue)
            #expect(Set(rawValues).count == allCases.count)
        }

        @Test
        func `rawValue for .file`() {
            #expect(File.Directory.Entry.Kind.file.rawValue == 0)
        }

        @Test
        func `rawValue for .directory`() {
            #expect(File.Directory.Entry.Kind.directory.rawValue == 1)
        }

        @Test
        func `rawValue for .symbolicLink`() {
            #expect(File.Directory.Entry.Kind.symbolicLink.rawValue == 2)
        }

        @Test
        func `rawValue for .other`() {
            #expect(File.Directory.Entry.Kind.other.rawValue == 3)
        }

        @Test
        func `rawValue round-trip for .file`() {
            let type = File.Directory.Entry.Kind.file
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test
        func `rawValue round-trip for .directory`() {
            let type = File.Directory.Entry.Kind.directory
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test
        func `rawValue round-trip for .symbolicLink`() {
            let type = File.Directory.Entry.Kind.symbolicLink
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test
        func `rawValue round-trip for .other`() {
            let type = File.Directory.Entry.Kind.other
            let restored = File.Directory.Entry.Kind(rawValue: type.rawValue)
            #expect(restored == type)
        }

        @Test
        func `Binary.Serializable - serialize produces correct byte`() {
            var buffer: [Byte] = []
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

    @Suite
    struct `EdgeCase` {
        @Test
        func `invalid rawValue returns nil`() {
            #expect(File.Directory.Entry.Kind(rawValue: 255) == nil)
        }

        @Test
        func `boundary rawValue (just past valid)`() {
            #expect(File.Directory.Entry.Kind(rawValue: 4) == nil)
        }

        @Test
        func `all invalid rawValues from 4 to 255 return nil`() {
            for rawValue in UInt8(4)...UInt8(255) {
                #expect(File.Directory.Entry.Kind(rawValue: Byte(rawValue)) == nil)
            }
        }
    }
}
