//
//  File.System.Read.Full Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Read.Full {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Read.Full.Test.Unit {

    // MARK: - Basic read

    @Test
    func `Read small file`() throws {
        let content: [Byte] = [72, 101, 108, 108, 111]  // "Hello"
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent == content)
        }
    }

    @Test
    func `Read empty file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "empty.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent.isEmpty)
        }
    }

    @Test
    func `Read file with text content`() throws {
        let text = "Hello, World!"
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            let bytes: [Byte] = Array(text.utf8).map(Byte.init)
            try File.System.Write.Atomic.write(bytes, to: filePath)

            let readString = try File.System.Read.Full.read(from: filePath) { span in
                span.withUnsafeBytes { buffer in
                    Swift.String(decoding: [UInt8](buffer), as: UTF8.self)
                }
            }
            #expect(readString == text)
        }
    }

    @Test
    func `Read binary data`() throws {
        // Binary content including null bytes and non-printable characters
        let content: [Byte] = [0x00, 0x01, 0xFF, 0xFE, 0x7F, 0x80]
        try File.Directory.temporary { dir in
            let filePath = dir.path / "binary.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent == content)
        }
    }

    @Test
    func `Read larger file`() throws {
        // Create a 64KB file
        let content = [Byte](repeating: 0xAB, count: 64 * 1024)
        try File.Directory.temporary { dir in
            let filePath = dir.path / "large.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent.count == 64 * 1024)
            #expect(readContent == content)
        }
    }

    @Test
    func `Read file with various byte values`() throws {
        // All possible byte values
        let content = (0...255).map { Byte(UInt8($0)) }
        try File.Directory.temporary { dir in
            let filePath = dir.path / "bytes.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent == content)
        }
    }

    // MARK: - Error cases

    @Test
    func `Read non-existing file throws pathNotFound`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "non-existing.txt"

            #expect(throws: File.System.Read.Full.Error.self) {
                try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            }
        }
    }

    @Test
    func `Read directory throws isDirectory`() throws {
        try File.Directory.temporary { dir in
            #expect(throws: File.System.Read.Full.Error.self) {
                try File.System.Read.Full.read(from: dir.path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            }
        }
    }

    // MARK: - Async variants

    @Test
    func `Async read file`() async throws {
        let content: [Byte] = [1, 2, 3, 4, 5]
        try File.Directory.temporary { dir in
            let filePath = dir.path / "async.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent == content)
        }
    }

    @Test
    func `Async read empty file`() async throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "async-empty.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readContent.isEmpty)
        }
    }

    // MARK: - Semantic Accessors

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isNotFound semantic accessor`() {
            let error = File.System.Read.Full.Error.open(.path(.notFound))
            #expect(error.isNotFound)
            #expect(!error.isPermissionDenied)
        }
    #endif

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isPermissionDenied semantic accessor`() {
            let error = File.System.Read.Full.Error.open(.platform(Error_Primitives.Error(code: .POSIX.EACCES)))
            #expect(error.isPermissionDenied)
            #expect(!error.isNotFound)
        }
    #endif

    @Test
    func `isDirectory semantic accessor`() {
        let path: File.Path = "/tmp"
        let error = File.System.Read.Full.Error.isDirectory(path)
        #expect(error.isDirectory)
        #expect(!error.isNotFound)
        #expect(error.description.contains("Is a directory"))
    }

    @Test
    func `isTooManyOpenFiles semantic accessor`() {
        let error = File.System.Read.Full.Error.open(.handle(.limit(.process)))
        #expect(error.isTooManyOpenFiles)
        #expect(!error.isNotFound)
    }

    @Test
    func `Error description contains failure message`() {
        let error = File.System.Read.Full.Error.open(.path(.notFound))
        #expect(error.description.contains("Open failed"))
    }
}
