//
//  File.Directory.Contents Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing
import TestingPerformance

@testable import File_System_Primitives

extension File.Directory.Contents {
    #TestSuites
}

extension File.Directory.Contents.Test.Unit {
    // MARK: - Listing

    @Test("List empty directory")
    func listEmptyDirectory() throws {
        try File.Directory.temporary { dir in
            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.isEmpty)
        }
    }

    @Test("List directory with files")
    func listDirectoryWithFiles() throws {
        try File.Directory.temporary { dir in
            // Create some files
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "file1.txt"))
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "file2.txt"))
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "file3.txt"))

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 3)

            let names = entries.compactMap { String($0.name) }.sorted()
            #expect(names == ["file1.txt", "file2.txt", "file3.txt"])
        }
    }

    @Test("List directory with subdirectories")
    func listDirectoryWithSubdirectories() throws {
        try File.Directory.temporary { dir in
            // Create subdirectories
            try File.System.Create.Directory.create(at: File.Path(dir.path, appending: "subdir1"))
            try File.System.Create.Directory.create(at: File.Path(dir.path, appending: "subdir2"))

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 2)

            for entry in entries {
                #expect(entry.type == .directory)
            }
        }
    }

    @Test("List directory with mixed content")
    func listDirectoryWithMixedContent() throws {
        try File.Directory.temporary { dir in
            // Create file
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "file.txt"))

            // Create subdirectory
            try File.System.Create.Directory.create(at: File.Path(dir.path, appending: "subdir"))

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 2)

            let fileEntry = entries.first { String($0.name) == "file.txt" }
            #expect(fileEntry?.type == .file)

            let dirEntry = entries.first { String($0.name) == "subdir" }
            #expect(dirEntry?.type == .directory)
        }
    }

    @Test("List directory excludes . and ..")
    func listDirectoryExcludesDotEntries() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "regular.txt"))

            let entries = try File.Directory.Contents.list(at: dir)

            let names = entries.compactMap { String($0.name) }
            #expect(!names.contains("."))
            #expect(!names.contains(".."))
        }
    }

    @Test("List directory with symlink")
    func listDirectoryWithSymlink() throws {
        try File.Directory.temporary { dir in
            // Create a regular file
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "target.txt"))

            // Create a symlink
            try File.System.Link.Symbolic.create(
                at: File.Path(dir.path, appending: "link.txt"),
                pointingTo: File.Path(dir.path, appending: "target.txt")
            )

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 2)

            let linkEntry = entries.first { String($0.name) == "link.txt" }
            #expect(linkEntry?.type == .symbolicLink)
        }
    }

    // MARK: - Entry Properties

    @Test("Entry has correct path")
    func entryHasCorrectPath() throws {
        try File.Directory.temporary { dir in
            try File.System.Write.Atomic.write([], to: File.Path(dir.path, appending: "test.txt"))

            let entries = try File.Directory.Contents.list(at: dir)
            #expect(entries.count == 1)

            let entry = entries[0]
            #expect(String(entry.name) == "test.txt")
            #expect(entry.pathIfValid?.string.hasSuffix("/test.txt") == true)
        }
    }

    // MARK: - Error Cases

    @Test("List non-existent directory throws pathNotFound")
    func listNonExistentDirectoryThrows() throws {
        try File.Directory.temporary { dir in
            let nonExistent = File.Path(dir.path, appending: "non-existent-\(Int.random(in: 0..<Int.max))")
            let nonExistentDir = File.Directory( nonExistent)

            #expect(throws: File.Directory.Contents.Error.self) {
                _ = try File.Directory.Contents.list(at: nonExistentDir)
            }
        }
    }

    @Test("List file throws notADirectory")
    func listFileThrowsNotADirectory() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test-file.txt")
            try File.System.Write.Atomic.write([], to: filePath)

            let fileAsDir = File.Directory( filePath)
            #expect(throws: File.Directory.Contents.Error.notADirectory(filePath)) {
                _ = try File.Directory.Contents.list(at: fileAsDir)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() {
        let path: File.Path = "/tmp/missing"
        let error = File.Directory.Contents.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() {
        let path: File.Path = "/root"
        let error = File.Directory.Contents.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("notADirectory error description")
    func notADirectoryErrorDescription() {
        let path: File.Path = "/tmp/file.txt"
        let error = File.Directory.Contents.Error.notADirectory(path)
        #expect(error.description.contains("Not a directory"))
    }

    @Test("readFailed error description")
    func readFailedErrorDescription() {
        let error = File.Directory.Contents.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Entry Type

    @Test("EntryType file case")
    func entryTypeFile() {
        let type: File.Directory.Entry.Kind = .file
        #expect(type == .file)
    }

    @Test("EntryType directory case")
    func entryTypeDirectory() {
        let type: File.Directory.Entry.Kind = .directory
        #expect(type == .directory)
    }

    @Test("EntryType symbolicLink case")
    func entryTypeSymbolicLink() {
        let type: File.Directory.Entry.Kind = .symbolicLink
        #expect(type == .symbolicLink)
    }

    @Test("EntryType other case")
    func entryTypeOther() {
        let type: File.Directory.Entry.Kind = .other
        #expect(type == .other)
    }
}

// MARK: - Performance Tests

extension File.Directory.Contents.Test.Performance {

    /// Performance tests using .timed() harness with class fixture for setup isolation.
    /// Setup runs once per test method (in init), not per .timed() iteration.
    @Suite(.serialized)
    final class DirectoryListingBenchmarks {
        let testDir: File.Directory

        init() throws {
            let td = try File.Directory.Temporary.system
            let testPath = File.Path(td.path, appending: "bench_\(Int.random(in: 0..<Int.max))")
            self.testDir = File.Directory( testPath)

            // Setup: create directory with 100 files
            // Use durability: .none to avoid F_FULLFSYNC overhead
            try File.System.Create.Directory.create(at: testPath)
            let fileData = [UInt8](repeating: 0x00, count: 10)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)
            for i in 0..<100 {
                let filePath = File.Path(testPath, appending: "file_\(i).txt")
                try File.System.Write.Atomic.write(
                    fileData.span,
                    to: filePath,
                    options: writeOptions
                )
            }
        }

        deinit {
            try? File.System.Delete.delete(at: testDir.path, options: .init(recursive: true))
        }

        @Test(
            "Directory contents listing (100 files)",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func directoryContentsListing() throws {
            let entries = try File.Directory.Contents.list(at: testDir)
            #expect(entries.count == 100)
        }

        @Test(
            "Directory iteration (100 files)",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func directoryIteration() throws {
            var iterator = try File.Directory.Iterator.open(at: testDir)
            var count = 0
            while try iterator.next() != nil {
                count += 1
            }
            iterator.close()
            #expect(count == 100)
        }
    }
}
