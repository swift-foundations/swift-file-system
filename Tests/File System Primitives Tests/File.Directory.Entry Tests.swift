//
//  File.Directory.Entry Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Entry {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Entry.Test.Unit {
    @Test("init with all properties")
    func initWithAllProperties() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("testfile.txt"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(String(entry.name) == "testfile.txt")
        #expect(try entry.path().string == "/tmp/testfile.txt")
        #expect(entry.type == .file)
    }

    @Test("init with directory type")
    func initWithDirectoryType() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("mydir"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .directory
        )

        #expect(String(entry.name) == "mydir")
        #expect(entry.type == .directory)
    }

    @Test("init with symbolic link type")
    func initWithSymbolicLinkType() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("mylink"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .symbolicLink
        )

        #expect(String(entry.name) == "mylink")
        #expect(entry.type == .symbolicLink)
    }

    @Test("init with other type")
    func initWithOtherType() throws {
        let parent = try File.Path("/dev")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("null"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .other
        )

        #expect(String(entry.name) == "null")
        #expect(entry.type == .other)
    }

    @Test("path is computed from parent and name")
    func pathComputedFromParentAndName() throws {
        let parent = try File.Path("/usr/local/bin")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("test"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(String(entry.name) == "test")
        #expect(try entry.path().string == "/usr/local/bin/test")
    }

    @Test("pathIfValid returns path for valid entry")
    func pathIfValidReturnsPath() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("valid.txt"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(entry.pathIfValid != nil)
        #expect(entry.pathIfValid?.string == "/tmp/valid.txt")
    }

    @Test("parent is accessible")
    func parentAccessible() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(entry.parent == parent)
    }
}

// MARK: - Edge Cases

extension File.Directory.Entry.Test.EdgeCase {
    @Test("entry with name containing spaces")
    func entryWithSpacesInName() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("my file.txt"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(String(entry.name) == "my file.txt")
        #expect(try entry.path().string == "/tmp/my file.txt")
    }

    @Test("entry with unicode name")
    func entryWithUnicodeName() throws {
        let parent = try File.Path("/tmp")
        // Use UTF-8 bytes directly for non-ASCII names
        let name = File.Name(rawBytes: Array("日本語ファイル.txt".utf8))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(String(entry.name) == "日本語ファイル.txt")
        #expect(try entry.path().string == "/tmp/日本語ファイル.txt")
    }

    @Test("entry with hidden file name")
    func entryWithHiddenFileName() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked(".hidden"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        #expect(String(entry.name) == ".hidden")
        #expect(entry.name.isHiddenByDotPrefix)
    }

    @Test("Entry is Sendable")
    func entrySendable() async throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        let result = await Task {
            (entry.name, entry.pathIfValid, entry.type)
        }.value

        #expect(String(result.0) == "file.txt")
        #expect(result.1?.string == "/tmp/file.txt")
        #expect(result.2 == .file)
    }

    @Test("Entry with undecodable name")
    func entryWithUndecodableName() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [0x80, 0x81, 0x82])  // Invalid UTF-8
        let entry = File.Directory.Entry(
            name: name,
            parent: parent,
            type: .file
        )

        // Name cannot be decoded to String
        #expect(String(entry.name) == nil)
        // But lossy decoding works
        #expect(String(lossy: entry.name).contains("\u{FFFD}"))
        // pathIfValid is nil for undecodable names
        #expect(entry.pathIfValid == nil)
        // path() throws for undecodable names
        #expect(throws: File.Path.Component.Error.self) {
            _ = try entry.path()
        }
        // Parent is still accessible
        #expect(entry.parent == parent)
    }

    @Test("Entry stored in collection")
    func entryInCollection() throws {
        let parent = try File.Path("/tmp")

        let entries: [File.Directory.Entry] = [
            File.Directory.Entry(
                name: File.Name(rawBytes: [UInt8].ascii.unchecked("file1.txt")),
                parent: parent,
                type: .file
            ),
            File.Directory.Entry(
                name: File.Name(rawBytes: [UInt8].ascii.unchecked("dir")),
                parent: parent,
                type: .directory
            ),
            File.Directory.Entry(
                name: File.Name(rawBytes: [0x80]),
                parent: parent,
                type: .file
            ),
        ]

        #expect(entries.count == 3)

        let filesCount = entries.filter { $0.type == .file }.count
        #expect(filesCount == 2)

        let withPath = entries.compactMap { $0.pathIfValid }
        #expect(withPath.count == 2)
    }
}
