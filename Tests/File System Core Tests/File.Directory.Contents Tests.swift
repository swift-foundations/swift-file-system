//
//  File.Directory.Contents Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Contents {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.Directory.Contents.Test.Unit {
    // MARK: - Listing

    @Test
    func `List empty directory`() throws {
        try File.Directory.temporary { dir in
            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.isEmpty)
        }
    }

    @Test
    func `List directory with files`() throws {
        try File.Directory.temporary { dir in
            // Create some files
            try File.System.Write.Atomic.write([], to: dir.path / "file1.txt")
            try File.System.Write.Atomic.write([], to: dir.path / "file2.txt")
            try File.System.Write.Atomic.write([], to: dir.path / "file3.txt")

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 3)

            let names = entries.compactMap { Swift.String($0.name) }.sorted()
            #expect(names == ["file1.txt", "file2.txt", "file3.txt"])
        }
    }

    @Test
    func `List directory with subdirectories`() throws {
        try File.Directory.temporary { dir in
            // Create subdirectories
            try File.System.Create.Directory.create(at: dir.path / "subdir1")
            try File.System.Create.Directory.create(at: dir.path / "subdir2")

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 2)

            for entry in entries {
                #expect(entry.type == .directory)
            }
        }
    }

    @Test
    func `List directory with mixed content`() throws {
        try File.Directory.temporary { dir in
            // Create file
            try File.System.Write.Atomic.write([], to: dir.path / "file.txt")

            // Create subdirectory
            try File.System.Create.Directory.create(at: dir.path / "subdir")

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 2)

            let fileEntry = entries.first { Swift.String($0.name) == "file.txt" }
            #expect(fileEntry?.type == .file)

            let dirEntry = entries.first { Swift.String($0.name) == "subdir" }
            #expect(dirEntry?.type == .directory)
        }
    }

    @Test
    func `List directory excludes . and ..`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "regular.txt")

            let entries = try File.Directory.Contents.list(at: dir)

            let names = entries.compactMap { Swift.String($0.name) }
            #expect(!names.contains("."))
            #expect(!names.contains(".."))
        }
    }

    #if !os(Windows)
        // Windows symlink handling differs - may return .other instead of .symbolicLink

        @Test
        func `List directory with symlink`() throws {
            try File.Directory.temporary { dir in
                // Create a regular file
                try File.System.Write.Atomic.write([], to: dir.path / "target.txt")

                // Create a symlink
                try File.System.Link.Symbolic.create(
                    at: dir.path / "link.txt",
                    pointingTo: dir.path / "target.txt"
                )

                let entries = try File.Directory.Contents.list(at: dir)
                #expect(entries.count == 2)

                let linkEntry = entries.first { Swift.String($0.name) == "link.txt" }
                #expect(linkEntry?.type == .symbolicLink)
            }
        }
    #endif

    // MARK: - Entry Properties

    @Test
    func `Entry has correct path`() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: dir.path / "test.txt")

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 1)

            let entry = entries[0]
            #expect(Swift.String(entry.name) == "test.txt")
            // Check the entry path ends with the filename (use platform-agnostic check)
            let expectedSuffix: File.Path = "test.txt"
            #expect(entry.pathIfValid?.components.last.map { Swift.String($0) } == expectedSuffix.components.last.map { Swift.String($0) })
        }
    }

    // MARK: - Error Cases

    @Test
    func `List non-existent directory throws pathNotFound`() throws {
        try File.Directory.temporary { dir in
            let nonExistent = dir.path / "non-existent-\(Int.random(in: (0..<Int.max)))"
            let nonExistentDir = File.Directory(nonExistent)

            #expect(throws: File.Directory.Contents.Error.self) {
                _ = try File.Directory.Contents.list(at: nonExistentDir)
            }
        }
    }

    @Test
    func `List file throws notADirectory`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test-file.txt"
            try File.System.Write.Atomic.write([], to: filePath)

            let fileAsDir = File.Directory(filePath)
            #expect(throws: File.Directory.Contents.Error.notADirectory(filePath)) {
                _ = try File.Directory.Contents.list(at: fileAsDir)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test
    func `pathNotFound error description`() {
        let path: File.Path = "/tmp/missing"
        let error = File.Directory.Contents.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test
    func `permissionDenied error description`() {
        let path: File.Path = "/root"
        let error = File.Directory.Contents.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test
    func `notADirectory error description`() {
        let path: File.Path = "/tmp/file.txt"
        let error = File.Directory.Contents.Error.notADirectory(path)
        #expect(error.description.contains("Not a directory"))
    }

    @Test
    func `readFailed error description`() {
        let error = File.Directory.Contents.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Entry Type

    @Test
    func `EntryType file case`() {
        let type: File.Directory.Entry.Kind = .file
        #expect(type == .file)
    }

    @Test
    func `EntryType directory case`() {
        let type: File.Directory.Entry.Kind = .directory
        #expect(type == .directory)
    }

    @Test
    func `EntryType symbolicLink case`() {
        let type: File.Directory.Entry.Kind = .symbolicLink
        #expect(type == .symbolicLink)
    }

    @Test
    func `EntryType other case`() {
        let type: File.Directory.Entry.Kind = .other
        #expect(type == .other)
    }
}
