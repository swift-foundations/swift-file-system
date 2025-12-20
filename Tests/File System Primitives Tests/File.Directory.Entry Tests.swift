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
        let path = try File.Path("/tmp/testfile.txt")
        let entry = File.Directory.Entry(
            name: "testfile.txt",
            path: path,
            type: .file
        )

        #expect(entry.name == "testfile.txt")
        #expect(entry.path == path)
        #expect(entry.type == .file)
    }

    @Test("init with directory type")
    func initWithDirectoryType() throws {
        let path = try File.Path("/tmp/mydir")
        let entry = File.Directory.Entry(
            name: "mydir",
            path: path,
            type: .directory
        )

        #expect(entry.name == "mydir")
        #expect(entry.type == .directory)
    }

    @Test("init with symbolic link type")
    func initWithSymbolicLinkType() throws {
        let path = try File.Path("/tmp/mylink")
        let entry = File.Directory.Entry(
            name: "mylink",
            path: path,
            type: .symbolicLink
        )

        #expect(entry.name == "mylink")
        #expect(entry.type == .symbolicLink)
    }

    @Test("init with other type")
    func initWithOtherType() throws {
        let path = try File.Path("/dev/null")
        let entry = File.Directory.Entry(
            name: "null",
            path: path,
            type: .other
        )

        #expect(entry.name == "null")
        #expect(entry.type == .other)
    }

    @Test("name property is independent of path")
    func namePropertyIndependent() throws {
        let path = try File.Path("/usr/local/bin/test")
        let entry = File.Directory.Entry(
            name: "custom_name",
            path: path,
            type: .file
        )

        // name is explicitly set, not derived from path
        #expect(entry.name == "custom_name")
        #expect(entry.path.string == "/usr/local/bin/test")
    }
}

// MARK: - Edge Cases

extension File.Directory.Entry.Test.EdgeCase {
    @Test("entry with empty name")
    func entryWithEmptyName() throws {
        let path = try File.Path("/tmp/test")
        let entry = File.Directory.Entry(
            name: "",
            path: path,
            type: .file
        )

        #expect(entry.name == "")
    }

    @Test("entry with name containing spaces")
    func entryWithSpacesInName() throws {
        let path = try File.Path("/tmp/my file.txt")
        let entry = File.Directory.Entry(
            name: "my file.txt",
            path: path,
            type: .file
        )

        #expect(entry.name == "my file.txt")
    }

    @Test("entry with unicode name")
    func entryWithUnicodeName() throws {
        let path = try File.Path("/tmp/日本語ファイル.txt")
        let entry = File.Directory.Entry(
            name: "日本語ファイル.txt",
            path: path,
            type: .file
        )

        #expect(entry.name == "日本語ファイル.txt")
    }

    @Test("entry with hidden file name")
    func entryWithHiddenFileName() throws {
        let path = try File.Path("/tmp/.hidden")
        let entry = File.Directory.Entry(
            name: ".hidden",
            path: path,
            type: .file
        )

        #expect(entry.name == ".hidden")
        #expect(entry.name.hasPrefix("."))
    }
}
