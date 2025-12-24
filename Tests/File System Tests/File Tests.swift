//
//  File Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System

extension File {
    #TestSuites
}

extension File.Test.Unit {

    // MARK: - Initializers

    @Test("init from path")
    func initFromPath() throws {
        let path = File.Path("/tmp/test.txt")
        let file = File(path)
        #expect(file.path == path)
    }

    @Test("init from string")
    func initFromString() throws {
        let file = try File(.init("/tmp/test.txt"))
        #expect(file.path == "/tmp/test.txt")
    }

    @Test("init from string literal")
    func initFromStringLiteral() {
        let file: File = .init("/tmp/test.txt")
        #expect(file.path == "/tmp/test.txt")
    }

    // MARK: - Read Operations

    @Test("read returns file contents")
    func readReturnsContents() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let file = dir["test.bin"]
            try file.write(content)

            let result: [UInt8] = try file.read()
            #expect(result == content)
        }
    }

    @Test("read async returns file contents")
    func readAsyncReturnsContents() async throws {
        try await File.Directory.temporary { dir in
            let content: [UInt8] = [10, 20, 30]
            let file = dir["test.bin"]
            try await file.write(content)

            let result: [UInt8] = try await file.read()
            #expect(result == content)
        }
    }

    @Test("read as String returns string contents")
    func readAsStringReturnsContents() throws {
        try File.Directory.temporary { dir in
            let text = "Hello, File!"
            let file = dir["test.txt"]
            try file.write(text)

            let result = try file.read(as: String.self)
            #expect(result == text)
        }
    }

    @Test("read as String async returns string contents")
    func readAsStringAsyncReturnsContents() async throws {
        try await File.Directory.temporary { dir in
            let text = "Async Hello!"
            let file = dir["test.txt"]
            try await file.write(text)

            let result = try await file.read(as: String.self)
            #expect(result == text)
        }
    }

    // MARK: - Write Operations

    @Test("write bytes to file")
    func writeBytesToFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            let content: [UInt8] = [1, 2, 3, 4, 5]
            try file.write(content)

            let readBack: [UInt8] = try file.read()
            #expect(readBack == content)
        }
    }

    @Test("write string to file")
    func writeStringToFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.txt"]
            let text = "Hello, World!"
            try file.write(text)

            let readBack = try file.read(as: String.self)
            #expect(readBack == text)
        }
    }

    @Test("write async bytes to file")
    func writeAsyncBytesToFile() async throws {
        try await File.Directory.temporary { dir in
            let file = dir["test.bin"]
            let content: [UInt8] = [10, 20, 30]
            try await file.write(content)

            let readBack: [UInt8] = try await file.read()
            #expect(readBack == content)
        }
    }

    // MARK: - Stat Operations

    @Test("exists returns true for existing file")
    func existsReturnsTrueForFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1, 2, 3])

            #expect(file.exists == true)
        }
    }

    @Test("exists returns false for non-existing file")
    func existsReturnsFalseForNonExisting() throws {
        try File.Directory.temporary { dir in
            let file = dir["non-existing.bin"]
            #expect(file.exists == false)
        }
    }

    @Test("isFile returns true for file")
    func isFileReturnsTrueForFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1])

            #expect(file.isFile == true)
        }
    }

    @Test("isDirectory returns false for file")
    func isDirectoryReturnsFalseForFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1])

            #expect(file.isDirectory == false)
        }
    }

    @Test("isSymlink returns false for regular file")
    func isSymlinkReturnsFalseForFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1])

            #expect(file.isSymlink == false)
        }
    }

    // MARK: - Metadata

    @Test("info returns file metadata")
    func infoReturnsMetadata() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let file = dir["test.bin"]
            try file.write(content)

            let info = try file.info
            #expect(info.size == Int64(content.count))
            #expect(info.type == .regular)
        }
    }

    @Test("size returns file size")
    func sizeReturnsFileSize() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let file = dir["test.bin"]
            try file.write(content)

            let size = try file.size
            #expect(size == 10)
        }
    }

    @Test("permissions returns file permissions")
    func permissionsReturnsPermissions() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1, 2, 3])

            let permissions = try file.permissions
            // File should be readable by owner at minimum
            #expect(permissions.contains(.ownerRead) == true)
        }
    }

    // MARK: - File Operations

    @Test("delete removes file")
    func deleteRemovesFile() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try file.write([1, 2, 3])

            #expect(file.exists == true)
            try file.delete()
            #expect(file.exists == false)
        }
    }

    @Test("delete async removes file")
    func deleteAsyncRemovesFile() async throws {
        try await File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try await file.write([1, 2, 3])

            #expect(file.exists == true)
            try await file.delete()
            #expect(file.exists == false)
        }
    }

    @Test("copy to path copies file")
    func copyToPathCopiesFile() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let source = dir["source.bin"]
            try source.write(content)

            let destPath = dir.path / "dest.bin"
            try source.copy(to: destPath)

            let dest = File(destPath)
            let readBack: [UInt8] = try dest.read()
            #expect(readBack == content)
        }
    }

    @Test("copy to file copies file")
    func copyToFileCopiesFile() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let source = dir["source.bin"]
            try source.write(content)

            let dest = dir["dest.bin"]
            try source.copy(to: dest)

            let readBack: [UInt8] = try dest.read()
            #expect(readBack == content)
        }
    }

    @Test("move to path moves file")
    func moveToPathMovesFile() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let source = dir["source.bin"]
            try source.write(content)

            let destPath = dir.path / "dest.bin"
            try source.move(to: destPath)

            let dest = File(destPath)
            #expect(source.exists == false)
            #expect(dest.exists == true)
            let readBack: [UInt8] = try dest.read()
            #expect(readBack == content)
        }
    }

    @Test("move to file moves file")
    func moveToFileMovesFile() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let source = dir["source.bin"]
            try source.write(content)

            let dest = dir["dest.bin"]
            try source.move(to: dest)

            #expect(source.exists == false)
            #expect(dest.exists == true)
        }
    }

    // MARK: - Path Navigation

    @Test("parent returns parent directory")
    func parentReturnsParent() {
        let file: File = .init("/tmp/subdir/file.txt")
        let parent = file.parent

        #expect(parent != nil)
        #expect(parent?.path == "/tmp/subdir")
    }

    @Test("name returns filename")
    func nameReturnsFilename() {
        let file: File = .init("/tmp/test.txt")
        #expect(file.name == "test.txt")
    }

    @Test("extension returns file extension")
    func extensionReturnsExtension() {
        let file: File = .init("/tmp/test.txt")
        #expect(file.extension == "txt")
    }

    @Test("extension returns nil for no extension")
    func extensionReturnsNilForNoExtension() {
        let file: File = .init("/tmp/Makefile")
        #expect(file.extension == nil)
    }

    @Test("stem returns filename without extension")
    func stemReturnsStem() {
        let file: File = .init("/tmp/test.txt")
        #expect(file.stem == "test")
    }

    @Test("appending returns new file with appended path")
    func appendingReturnsNewFile() {
        let file: File = .init("/tmp")
        let result = file.appending("subdir")
        #expect(result.path == "/tmp/subdir")
    }

    @Test("/ operator appends path")
    func slashOperatorAppendsPath() {
        let file: File = .init("/tmp")
        let result = file / "subdir" / "file.txt"
        #expect(result.path == "/tmp/subdir/file.txt")
    }

    // MARK: - Hashable & Equatable

    @Test("File is equatable")
    func fileIsEquatable() throws {
        let file1 = try File(.init("/tmp/test.txt"))
        let file2 = try File(.init("/tmp/test.txt"))
        let file3 = try File(.init("/tmp/other.txt"))

        #expect(file1 == file2)
        #expect(file1 != file3)
    }

    @Test("File is hashable")
    func fileIsHashable() throws {
        let file1 = try File(.init("/tmp/test.txt"))
        let file2 = try File(.init("/tmp/test.txt"))

        var set = Set<File>()
        set.insert(file1)
        set.insert(file2)

        #expect(set.count == 1)
    }

    // MARK: - CustomStringConvertible

    @Test("description returns path string")
    func descriptionReturnsPathString() {
        let file: File = .init("/tmp/test.txt")
        let expected: File.Path = "/tmp/test.txt"
        #expect(file.description == String(expected))
    }

    @Test("debugDescription returns formatted string")
    func debugDescriptionReturnsFormatted() {
        let file: File = .init("/tmp/test.txt")
        let p: File.Path = "/tmp/test.txt"
        #expect(file.debugDescription == "File(\(String(p).debugDescription))")
    }
}
