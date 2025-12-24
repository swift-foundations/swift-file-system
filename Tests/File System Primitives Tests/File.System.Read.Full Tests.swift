//
//  File.System.Read.Full Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Read.Full {
    #TestSuites
}

extension File.System.Read.Full.Test.Unit {

    // MARK: - Basic read

    @Test("Read small file")
    func readSmallFile() throws {
        let content: [UInt8] = [72, 101, 108, 108, 111]  // "Hello"
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent == content)
        }
    }

    @Test("Read empty file")
    func readEmptyFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "empty.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent.isEmpty)
        }
    }

    @Test("Read file with text content")
    func readFileWithTextContent() throws {
        let text = "Hello, World!"
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")
            try File.System.Write.Atomic.write(Array(text.utf8).span, to: filePath)

            let readString = String(
                decoding: try File.System.Read.Full.read(from: filePath),
                as: UTF8.self
            )
            #expect(readString == text)
        }
    }

    @Test("Read binary data")
    func readBinaryData() throws {
        // Binary content including null bytes and non-printable characters
        let content: [UInt8] = [0x00, 0x01, 0xFF, 0xFE, 0x7F, 0x80]
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "binary.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent == content)
        }
    }

    @Test("Read larger file")
    func readLargerFile() throws {
        // Create a 64KB file
        let content = [UInt8](repeating: 0xAB, count: 64 * 1024)
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "large.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent.count == 64 * 1024)
            #expect(readContent == content)
        }
    }

    @Test("Read file with various byte values")
    func readFileWithVariousByteValues() throws {
        // All possible byte values
        let content = (0...255).map { UInt8($0) }
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "bytes.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent == content)
        }
    }

    // MARK: - Error cases

    @Test("Read non-existing file throws pathNotFound")
    func readNonExistingFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "non-existing.txt")

            #expect(throws: File.System.Read.Full.Error.self) {
                try File.System.Read.Full.read(from: filePath)
            }
        }
    }

    @Test("Read directory throws isDirectory")
    func readDirectory() throws {
        try File.Directory.temporary { dir in
            #expect(throws: File.System.Read.Full.Error.self) {
                try File.System.Read.Full.read(from: dir.path)
            }
        }
    }

    // MARK: - Async variants

    @Test("Async read file")
    func asyncReadFile() async throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "async.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent == content)
        }
    }

    @Test("Async read empty file")
    func asyncReadEmptyFile() async throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "async-empty.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let readContent = try File.System.Read.Full.read(from: filePath)
            #expect(readContent.isEmpty)
        }
    }

    // MARK: - Error descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() {
        let path: File.Path = "/tmp/missing.txt"
        let error = File.System.Read.Full.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
        #expect(error.description.contains(String(path)))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() {
        let path: File.Path = "/root/secret.txt"
        let error = File.System.Read.Full.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() {
        let path: File.Path = "/tmp"
        let error = File.System.Read.Full.Error.isDirectory(path)
        #expect(error.description.contains("Is a directory"))
    }

    @Test("readFailed error description")
    func readFailedErrorDescription() {
        let error = File.System.Read.Full.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read failed"))
        #expect(error.description.contains("I/O error"))
        #expect(error.description.contains("5"))
    }

    @Test("tooManyOpenFiles error description")
    func tooManyOpenFilesErrorDescription() {
        let error = File.System.Read.Full.Error.tooManyOpenFiles
        #expect(error.description.contains("Too many open files"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() {
        let path1: File.Path = "/tmp/a"
        let path2: File.Path = "/tmp/a"
        let path3: File.Path = "/tmp/b"

        #expect(
            File.System.Read.Full.Error.pathNotFound(path1)
                == File.System.Read.Full.Error.pathNotFound(path2)
        )
        #expect(
            File.System.Read.Full.Error.pathNotFound(path1)
                != File.System.Read.Full.Error.pathNotFound(path3)
        )
        #expect(
            File.System.Read.Full.Error.pathNotFound(path1)
                != File.System.Read.Full.Error.permissionDenied(path1)
        )
        #expect(
            File.System.Read.Full.Error.tooManyOpenFiles
                == File.System.Read.Full.Error.tooManyOpenFiles
        )
    }
}

// MARK: - Performance Tests

extension File.System.Read.Full.Test.Performance {

    @Test("File.System.Read.Full.read (1MB)", .timed(iterations: 10, warmup: 2))
    func systemRead1MB() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td.path,
            appending: "perf_sysread_\(Int.random(in: 0..<Int.max)).bin"
        )

        // Setup
        let oneMB = [UInt8](repeating: 0xBE, count: 1_000_000)
        try File.System.Write.Atomic.write(oneMB.span, to: filePath)

        defer { try? File.System.Delete.delete(at: filePath) }

        let _ = try File.System.Read.Full.read(from: filePath)
    }
}
