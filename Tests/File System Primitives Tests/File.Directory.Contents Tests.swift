//
//  File.Directory.Contents Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Contents {
    #TestSuites
}

extension File.Directory.Contents.Test.Unit {
    // MARK: - Test Fixtures
    
    private func writeBytes(_ bytes: [UInt8], to path: File.Path) throws {
        var bytes = bytes
        try bytes.withUnsafeMutableBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
    }
    
    private func createTempDir() throws -> String {
        let path = "/tmp/contents-test-\(Int.random(in: 0..<Int.max))"
        try File.System.Create.Directory.create(at: try File.Path(path))
        return path
    }
    
    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }
    
    // MARK: - Listing
    
    @Test("List empty directory")
    func listEmptyDirectory() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.isEmpty)
    }
    
    @Test("List directory with files")
    func listDirectoryWithFiles() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        // Create some files
        try writeBytes([], to: try File.Path("\(dirPath)/file1.txt"))
        try writeBytes([], to: try File.Path("\(dirPath)/file2.txt"))
        try writeBytes([], to: try File.Path("\(dirPath)/file3.txt"))
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.count == 3)
        
        let names = entries.compactMap { String($0.name) }.sorted()
        #expect(names == ["file1.txt", "file2.txt", "file3.txt"])
    }
    
    @Test("List directory with subdirectories")
    func listDirectoryWithSubdirectories() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        // Create subdirectories
        try File.System.Create.Directory.create(at: try File.Path("\(dirPath)/subdir1"))
        try File.System.Create.Directory.create(at: try File.Path("\(dirPath)/subdir2"))
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.count == 2)
        
        for entry in entries {
            #expect(entry.type == .directory)
        }
    }
    
    @Test("List directory with mixed content")
    func listDirectoryWithMixedContent() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        // Create file
        try writeBytes([], to: try File.Path("\(dirPath)/file.txt"))
        
        // Create subdirectory
        try File.System.Create.Directory.create(at: try File.Path("\(dirPath)/subdir"))
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.count == 2)
        
        let fileEntry = entries.first { String($0.name) == "file.txt" }
        #expect(fileEntry?.type == .file)
        
        let dirEntry = entries.first { String($0.name) == "subdir" }
        #expect(dirEntry?.type == .directory)
    }
    
    @Test("List directory excludes . and ..")
    func listDirectoryExcludesDotEntries() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        try writeBytes([], to: try File.Path("\(dirPath)/regular.txt"))
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        
        let names = entries.compactMap { String($0.name) }
        #expect(!names.contains("."))
        #expect(!names.contains(".."))
    }
    
    @Test("List directory with symlink")
    func listDirectoryWithSymlink() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        // Create a regular file
        try writeBytes([], to: try File.Path("\(dirPath)/target.txt"))
        
        // Create a symlink
        try File.System.Link.Symbolic.create(
            at: try File.Path("\(dirPath)/link.txt"),
            pointingTo: try File.Path("\(dirPath)/target.txt")
        )
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.count == 2)
        
        let linkEntry = entries.first { String($0.name) == "link.txt" }
        #expect(linkEntry?.type == .symbolicLink)
    }
    
    // MARK: - Entry Properties
    
    @Test("Entry has correct path")
    func entryHasCorrectPath() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }
        
        try writeBytes([], to: try File.Path("\(dirPath)/test.txt"))
        
        let path = try File.Path(dirPath)
        let entries = try File.Directory.Contents.list(at: path)
        #expect(entries.count == 1)
        
        let entry = entries[0]
        #expect(String(entry.name) == "test.txt")
        #expect(entry.pathIfValid?.string.hasSuffix("/test.txt") == true)
    }
    
    // MARK: - Error Cases
    
    @Test("List non-existent directory throws pathNotFound")
    func listNonExistentDirectoryThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)
        
        #expect(throws: File.Directory.Contents.Error.self) {
            _ = try File.Directory.Contents.list(at: path)
        }
    }
    
    @Test("List file throws notADirectory")
    func listFileThrowsNotADirectory() throws {
        let filePath = "/tmp/contents-file-\(Int.random(in: 0..<Int.max)).txt"
        defer {
            if let path = try? File.Path(filePath) {
                try? File.System.Delete.delete(at: path)
            }
        }
        
        try writeBytes([], to: try File.Path(filePath))
        
        let path = try File.Path(filePath)
        
        #expect(throws: File.Directory.Contents.Error.notADirectory(path)) {
            _ = try File.Directory.Contents.list(at: path)
        }
    }
    
    // MARK: - Error Descriptions
    
    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.Directory.Contents.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }
    
    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root")
        let error = File.Directory.Contents.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }
    
    @Test("notADirectory error description")
    func notADirectoryErrorDescription() throws {
        let path = try File.Path("/tmp/file.txt")
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

#if canImport(Foundation)
import Foundation
#endif

import TestingPerformance

extension File.Directory.Contents.Test.Performance {

    /// Performance tests using .timed() harness with class fixture for setup isolation.
    /// Setup runs once per test method (in init), not per .timed() iteration.
    @Suite(.serialized)
    final class DirectoryListingBenchmarks {
        let testDir: File.Path

        init() throws {
            #if canImport(Foundation)
                let tempDir = try File.Path(NSTemporaryDirectory())
            #else
                let tempDir = try File.Path("/tmp")
            #endif
            self.testDir = File.Path(tempDir, appending: "bench_\(Int.random(in: 0..<Int.max))")

            // Setup: create directory with 100 files
            // Use durability: .none to avoid F_FULLFSYNC overhead
            try File.System.Create.Directory.create(at: testDir)
            let fileData = [UInt8](repeating: 0x00, count: 10)
            let writeOptions = File.System.Write.Atomic.Options(durability: .none)
            for i in 0..<100 {
                let filePath = File.Path(testDir, appending: "file_\(i).txt")
                try fileData.withUnsafeBufferPointer { buffer in
                    let span = Span<UInt8>(_unsafeElements: buffer)
                    try File.System.Write.Atomic.write(span, to: filePath, options: writeOptions)
                }
            }
        }

        deinit {
            try? File.System.Delete.delete(at: testDir, options: .init(recursive: true))
        }

        @Test("Directory contents listing (100 files)", .timed(iterations: 50, warmup: 5, trackAllocations: false))
        func directoryContentsListing() throws {
            let entries = try File.Directory.Contents.list(at: testDir)
            #expect(entries.count == 100)
        }

        @Test("Directory iteration (100 files)", .timed(iterations: 50, warmup: 5, trackAllocations: false))
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
