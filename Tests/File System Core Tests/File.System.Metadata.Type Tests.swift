//
//  File.System.Metadata.Kind Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

// Note: Cannot use #Tests macro due to `Type` being a Swift keyword

@Suite
struct `File.System.Metadata.Kind Tests` {
    @Suite("Unit")
    struct Unit {
        @Test
        func `all cases are distinct`() {
            let allCases: [File.System.Metadata.Kind] = [
                .regular, .directory, .symbolicLink, .blockDevice,
                .characterDevice, .fifo, .socket,
            ]
            let rawValues = allCases.map(\.rawValue)
            #expect(Set(rawValues).count == allCases.count)
        }

        @Test
        func `rawValue for .regular`() {
            #expect(File.System.Metadata.Kind.regular.rawValue == 0)
        }

        @Test
        func `rawValue for .directory`() {
            #expect(File.System.Metadata.Kind.directory.rawValue == 1)
        }

        @Test
        func `rawValue for .symbolicLink`() {
            #expect(File.System.Metadata.Kind.symbolicLink.rawValue == 2)
        }

        @Test
        func `rawValue for .blockDevice`() {
            #expect(File.System.Metadata.Kind.blockDevice.rawValue == 3)
        }

        @Test
        func `rawValue for .characterDevice`() {
            #expect(File.System.Metadata.Kind.characterDevice.rawValue == 4)
        }

        @Test
        func `rawValue for .fifo`() {
            #expect(File.System.Metadata.Kind.fifo.rawValue == 5)
        }

        @Test
        func `rawValue for .socket`() {
            #expect(File.System.Metadata.Kind.socket.rawValue == 6)
        }

        @Test
        func `rawValue round-trip for all cases`() {
            let allCases: [File.System.Metadata.Kind] = [
                .regular, .directory, .symbolicLink, .blockDevice,
                .characterDevice, .fifo, .socket,
            ]
            for type in allCases {
                let restored = File.System.Metadata.Kind(rawValue: type.rawValue)
                #expect(restored == type)
            }
        }

        @Test
        func `Binary.Serializable - serialize produces correct bytes`() {
            var buffer: [Byte] = []
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

    @Suite
    struct `EdgeCase` {
        @Test
        func `invalid rawValue returns nil`() {
            #expect(File.System.Metadata.Kind(rawValue: 255) == nil)
        }

        @Test
        func `boundary rawValue (just past valid)`() {
            #expect(File.System.Metadata.Kind(rawValue: 7) == nil)
        }

        @Test
        func `all invalid rawValues from 7 to 255 return nil`() {
            for rawValue in UInt8(7)...UInt8(255) {
                #expect(File.System.Metadata.Kind(rawValue: Byte(rawValue)) == nil)
            }
        }
    }
}
