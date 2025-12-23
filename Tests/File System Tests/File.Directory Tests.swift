//
//  File.Directory Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System

extension File.Directory {
    #TestSuites
}

extension File.Directory.Test.Unit {

    // MARK: - Initializers

    @Test("init from path")
    func initFromPath() {
        let path: File.Path = "/tmp/test"
        let dir = File.Directory(path)
        #expect(dir.path == path)
    }

    @Test("init from string")
    func initFromString() throws {
        let dir = try File.Directory("/tmp/test")
        #expect(dir.description == "/tmp/test")
    }

    // Removed: init from string literal test - File.Directory intentionally does not conform to ExpressibleByStringLiteral

    // MARK: - Directory Operations

    @Test("create creates directory")
    func createCreatesDirectory() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.subdirectory("test")

            #expect(testDir.exists == false)
            try testDir.create()
            #expect(testDir.exists == true)
            #expect(testDir.isDirectory == true)
        }
    }

    @Test("create with intermediates")
    func createWithIntermediates() throws {
        try File.Directory.temporary { dir in
            let nested = dir.subdirectory("nested").subdirectory("path")

            #expect(nested.exists == false)
            try nested.create(recursive: true)
            #expect(nested.exists == true)
        }
    }

    @Test("create async creates directory")
    func createAsyncCreatesDirectory() async throws {
        try await File.Directory.temporary { dir in
            let testDir = dir.subdirectory("async-test")

            try await testDir.create()
            #expect(testDir.isDirectory == true)
        }
    }

    @Test("delete removes empty directory")
    func deleteRemovesEmptyDirectory() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.subdirectory("test")
            try testDir.create()

            #expect(testDir.exists == true)
            try testDir.delete()
            #expect(testDir.exists == false)
        }
    }

    @Test("delete recursive removes directory with contents")
    func deleteRecursiveRemovesContents() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.subdirectory("test")
            try testDir.create()
            let file = testDir["test.txt"]
            try file.write("test")

            #expect(testDir.exists == true)
            try testDir.delete(recursive: true)
            #expect(testDir.exists == false)
        }
    }

    @Test("delete async removes directory")
    func deleteAsyncRemovesDirectory() async throws {
        try await File.Directory.temporary { dir in
            let testDir = dir.subdirectory("test")
            try await testDir.create()

            #expect(testDir.exists == true)
            try await testDir.delete()
            #expect(testDir.exists == false)
        }
    }

    // MARK: - Stat Operations

    @Test("exists returns true for existing directory")
    func existsReturnsTrueForDirectory() throws {
        try File.Directory.temporary { dir in
            #expect(dir.exists == true)
        }
    }

    @Test("exists returns false for non-existing directory")
    func existsReturnsFalseForNonExisting() throws {
        try File.Directory.temporary { dir in
            let nonExisting = dir.subdirectory("non-existing")
            #expect(nonExisting.exists == false)
        }
    }

    @Test("isDirectory returns true for directory")
    func isDirectoryReturnsTrueForDirectory() throws {
        try File.Directory.temporary { dir in
            #expect(dir.isDirectory == true)
        }
    }

    // MARK: - Contents

    @Test("contents returns directory entries")
    func contentsReturnsEntries() throws {
        try File.Directory.temporary { dir in
            // Create some files
            try dir["file1.txt"].write("content1")
            try dir["file2.txt"].write("content2")

            let contents = try dir.contents()
            let names = contents.compactMap { String($0.name) }.sorted()

            #expect(names == ["file1.txt", "file2.txt"])
        }
    }

    @Test("contents async returns directory entries")
    func contentsAsyncReturnsEntries() async throws {
        try await File.Directory.temporary { dir in
            try await dir["test.txt"].write("test")

            let contents = try await dir.contents()
            #expect(contents.count == 1)
            #expect(String(contents[0].name) == "test.txt")
        }
    }

    @Test("files returns only files")
    func filesReturnsOnlyFiles() throws {
        try File.Directory.temporary { dir in
            // Create file and subdirectory
            try dir["file.txt"].write("content")
            try dir.subdirectory("subdir").create()

            let files = try dir.files()
            #expect(files.count == 1)
            #expect(files[0].path.lastComponent?.string == "file.txt")
        }
    }

    @Test("subdirectories returns only directories")
    func subdirectoriesReturnsOnlyDirs() throws {
        try File.Directory.temporary { dir in
            // Create file and subdirectory
            try dir["file.txt"].write("content")
            try dir.subdirectory("subdir").create()

            let subdirs = try dir.subdirectories()
            #expect(subdirs.count == 1)
            #expect(subdirs[0].name == "subdir")
        }
    }

    // MARK: - Subscript Access

    @Test("subscript returns File")
    func subscriptReturnsFile() throws {
        let dir = try File.Directory("/tmp/mydir")
        let file = dir["readme.txt"]

        #expect(file.path.string == "/tmp/mydir/readme.txt")
    }

    @Test("subscript chain works")
    func subscriptChainWorks() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.txt"]
            try file.write("Hello")

            let readBack = try dir["test.txt"].read(as: String.self)
            #expect(readBack == "Hello")
        }
    }

    @Test("subdirectory returns Directory.Instance")
    func subdirectoryReturnsDirectoryInstance() throws {
        let dir = try File.Directory("/tmp/mydir")
        let subdir = dir.subdirectory("nested")

        #expect(subdir.description == "/tmp/mydir/nested")
    }

    // MARK: - Path Navigation

    @Test("parent returns parent directory")
    func parentReturnsParent() throws {
        let dir = try File.Directory("/tmp/parent/child")
        let parent = dir.parent

        #expect(parent != nil)
        #expect(parent?.path.string == "/tmp/parent")
    }

    @Test("name returns directory name")
    func nameReturnsDirectoryName() throws {
        let dir = try File.Directory("/tmp/mydir")
        #expect(dir.name == "mydir")
    }

    @Test("appending returns new instance")
    func appendingReturnsNewInstance() throws {
        let dir = try File.Directory("/tmp")
        let result = dir.appending("subdir")
        #expect(result.path.string == "/tmp/subdir")
    }

    @Test("/ operator appends path")
    func slashOperatorAppendsPath() throws {
        let dir = try File.Directory("/tmp")
        let result = dir / "subdir" / "nested"
        #expect(result.path.string == "/tmp/subdir/nested")
    }

    // MARK: - Hashable & Equatable

    @Test("File.Directory is equatable")
    func directoryIsEquatable() throws {
        let dir1 = try File.Directory("/tmp/test")
        let dir2 = try File.Directory("/tmp/test")
        let dir3 = try File.Directory("/tmp/other")

        #expect(dir1 == dir2)
        #expect(dir1 != dir3)
    }

    @Test("File.Directory is hashable")
    func directoryIsHashable() throws {
        let dir1 = try File.Directory("/tmp/test")
        let dir2 = try File.Directory("/tmp/test")

        var set = Set<File.Directory>()
        set.insert(dir1)
        set.insert(dir2)

        #expect(set.count == 1)
    }

    // MARK: - CustomStringConvertible

    @Test("description returns path string")
    func descriptionReturnsPathString() throws {
        let dir = try File.Directory("/tmp/test")
        #expect(dir.description == "/tmp/test")
    }

    @Test("debugDescription returns formatted string")
    func debugDescriptionReturnsFormatted() throws {
        let dir = try File.Directory("/tmp/test")
        #expect(dir.debugDescription == #"File.Directory("/tmp/test")"#)
    }
}
