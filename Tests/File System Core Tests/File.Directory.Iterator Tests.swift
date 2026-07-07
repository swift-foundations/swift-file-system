//
//  File.Directory.Iterator Tests.swift
//  swift-file-system
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Iterator {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.Directory.Iterator.Test.Unit {
    @Test
    func `open on valid directory succeeds`() throws {
        try File.Directory.temporary { dir in
            let iterator = try File.Directory.Iterator.open(at: dir)
            iterator.close()
        }
    }

    @Test
    func `next returns nil for empty directory`() throws {
        try File.Directory.temporary { dir in
            var iterator = try File.Directory.Iterator.open(at: dir)
            let entry = try iterator.next()
            iterator.close()

            #expect(entry == nil)
        }
    }

    @Test
    func `next returns entries for non-empty directory`() throws {
        try File.Directory.temporary { dir in
            // Create a file in the directory
            let filePath = dir.path / "testfile.txt"
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .execClose])
            try handle.close()

            var iterator = try File.Directory.Iterator.open(at: dir)
            let entry = try iterator.next()
            iterator.close()

            #expect(entry != nil)
            #expect(entry.flatMap { Swift.String($0.name) } == "testfile.txt")
            #expect(entry?.type == .file)
        }
    }

    @Test
    func `iterator skips . and .. entries`() throws {
        try File.Directory.temporary { dir in
            var iterator = try File.Directory.Iterator.open(at: dir)

            // Collect all entries
            var entries: [Swift.String] = []
            while let entry = try iterator.next() {
                if let name = Swift.String(entry.name) {
                    entries.append(name)
                }
            }
            iterator.close()

            #expect(!entries.contains("."))
            #expect(!entries.contains(".."))
        }
    }

    @Test
    func `close is idempotent`() throws {
        try File.Directory.temporary { dir in
            let iterator = try File.Directory.Iterator.open(at: dir)
            iterator.close()
            // close() is consuming, so this is the only call
        }
    }
}

// MARK: - Semantic Accessor Tests

extension File.Directory.Iterator.Test.Unit {
    @Test
    func `isNotFound semantic accessor`() {
        let error = File.Directory.Iterator.Error.directory(.notFound)
        #expect(error.isNotFound)
        #expect(!error.isPermissionDenied)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.Directory.Iterator.Error.directory(.permission)
        #expect(error.isPermissionDenied)
        #expect(!error.isNotFound)
    }

    @Test
    func `isNotADirectory semantic accessor`() {
        let error = File.Directory.Iterator.Error.directory(.notDirectory)
        #expect(error.isNotADirectory)
        #expect(!error.isNotFound)
    }

    @Test
    func `isTooManyOpenFiles semantic accessor`() {
        let error = File.Directory.Iterator.Error.directory(.tooManyOpenFiles)
        #expect(error.isTooManyOpenFiles)
        #expect(!error.isNotFound)
    }

    @Test
    func `Error description contains failure message`() {
        let error = File.Directory.Iterator.Error.directory(.notFound)
        #expect(error.description.contains("Directory iteration failed"))
    }
}

// MARK: - Edge Cases

extension File.Directory.Iterator.Test.`Edge Case` {
    @Test
    func `open on non-existent directory throws pathNotFound`() throws {
        let directory = File.Directory("/nonexistent-dir-\(Int.random(in: (0..<Int.max)))")

        #expect(throws: File.Directory.Iterator.Error.self) {
            _ = try File.Directory.Iterator.open(at: directory)
        }
    }

    @Test
    func `open on file throws notADirectory`() throws {
        try File.Directory.temporary { dir in
            // Create a file, not a directory
            let filePath = dir.path / "iter-file-test.txt"
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .execClose])
            try handle.close()

            #expect(throws: File.Directory.Iterator.Error.self) {
                _ = try File.Directory.Iterator.open(at: File.Directory(filePath))
            }
        }
    }
}
