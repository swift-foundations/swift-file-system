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
        let path = try File.Path("/tmp/testfile.txt")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("testfile.txt"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        #expect(String(entry.name) == "testfile.txt")
        #expect(entry.path == path)
        #expect(entry.type == .file)
    }

    @Test("init with directory type")
    func initWithDirectoryType() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/mydir")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("mydir"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .directory
        )

        #expect(String(entry.name) == "mydir")
        #expect(entry.type == .directory)
    }

    @Test("init with symbolic link type")
    func initWithSymbolicLinkType() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/mylink")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("mylink"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .symbolicLink
        )

        #expect(String(entry.name) == "mylink")
        #expect(entry.type == .symbolicLink)
    }

    @Test("init with other type")
    func initWithOtherType() throws {
        let parent = try File.Path("/dev")
        let path = try File.Path("/dev/null")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("null"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .other
        )

        #expect(String(entry.name) == "null")
        #expect(entry.type == .other)
    }

    @Test("name property is independent of path")
    func namePropertyIndependent() throws {
        let parent = try File.Path("/usr/local/bin")
        let path = try File.Path("/usr/local/bin/test")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("custom_name"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        // name is explicitly set, not derived from path
        #expect(String(entry.name) == "custom_name")
        #expect(entry.path?.string == "/usr/local/bin/test")
    }

    @Test("relative location has no path")
    func relativeLocationHasNoPath() throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("undecodable"))
        let entry = File.Directory.Entry(
            name: name,
            location: .relative(parent: parent),
            type: .file
        )

        #expect(entry.path == nil)
        #expect(entry.parent == parent)
    }

    @Test("parent is accessible from both location types")
    func parentAccessibleFromBothTypes() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")

        let absoluteEntry = File.Directory.Entry(
            name: File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt")),
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        let relativeEntry = File.Directory.Entry(
            name: File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt")),
            location: .relative(parent: parent),
            type: .file
        )

        #expect(absoluteEntry.parent == parent)
        #expect(relativeEntry.parent == parent)
    }
}

// MARK: - Edge Cases

extension File.Directory.Entry.Test.EdgeCase {
    @Test("entry with name containing spaces")
    func entryWithSpacesInName() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/my file.txt")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("my file.txt"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        #expect(String(entry.name) == "my file.txt")
    }

    @Test("entry with unicode name")
    func entryWithUnicodeName() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/日本語ファイル.txt")
        // Use UTF-8 bytes directly for non-ASCII names
        let name = File.Name(rawBytes: Array("日本語ファイル.txt".utf8))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        #expect(String(entry.name) == "日本語ファイル.txt")
    }

    @Test("entry with hidden file name")
    func entryWithHiddenFileName() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/.hidden")
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked(".hidden"))
        let entry = File.Directory.Entry(
            name: name,
            location: .absolute(parent: parent, path: path),
            type: .file
        )

        #expect(String(entry.name) == ".hidden")
        #expect(entry.name.isHiddenByDotPrefix)
    }
}
