//
//  File.Directory.Iterator Tests.swift
//  swift-file-system
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Iterator {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Iterator.Test.Unit {
    @Test("open on valid directory succeeds")
    func openValidDirectory() throws {
        try File.Directory.temporary { dir in
            let iterator = try File.Directory.Iterator.open(at: dir)
            iterator.close()
        }
    }

    @Test("next returns nil for empty directory")
    func nextReturnsNilForEmptyDirectory() throws {
        try File.Directory.temporary { dir in
            var iterator = try File.Directory.Iterator.open(at: dir)
            let entry = try iterator.next()
            iterator.close()

            #expect(entry == nil)
        }
    }

    @Test("next returns entries for non-empty directory")
    func nextReturnsEntriesForNonEmptyDirectory() throws {
        try File.Directory.temporary { dir in
            // Create a file in the directory
            let filePath = File.Path(dir.path, appending: "testfile.txt")
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
            try handle.close()

            var iterator = try File.Directory.Iterator.open(at: dir)
            let entry = try iterator.next()
            iterator.close()

            #expect(entry != nil)
            #expect(entry.flatMap { String($0.name) } == "testfile.txt")
            #expect(entry?.type == .file)
        }
    }

    @Test("iterator skips . and .. entries")
    func iteratorSkipsDotEntries() throws {
        try File.Directory.temporary { dir in
            var iterator = try File.Directory.Iterator.open(at: dir)

            // Collect all entries
            var entries: [String] = []
            while let entry = try iterator.next() {
                if let name = String(entry.name) {
                    entries.append(name)
                }
            }
            iterator.close()

            #expect(!entries.contains("."))
            #expect(!entries.contains(".."))
        }
    }

    @Test("close is idempotent")
    func closeIsIdempotent() throws {
        try File.Directory.temporary { dir in
            let iterator = try File.Directory.Iterator.open(at: dir)
            iterator.close()
            // close() is consuming, so this is the only call
        }
    }
}

// MARK: - Error Tests

extension File.Directory.Iterator.Test.Unit {
    @Test("Error.pathNotFound description")
    func errorPathNotFoundDescription() throws {
        let path: File.Path = "/nonexistent"
        let error = File.Directory.Iterator.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
        #expect(error.description.contains(String(path)))
    }

    @Test("Error.permissionDenied description")
    func errorPermissionDeniedDescription() throws {
        let path = File.Path("/protected")
        let error = File.Directory.Iterator.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("Error.notADirectory description")
    func errorNotADirectoryDescription() throws {
        let path = File.Path("/tmp/file.txt")
        let error = File.Directory.Iterator.Error.notADirectory(path)
        #expect(error.description.contains("Not a directory"))
    }

    @Test("Error.readFailed description")
    func errorReadFailedDescription() {
        let error = File.Directory.Iterator.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read failed"))
        #expect(error.description.contains("I/O error"))
        #expect(error.description.contains("5"))
    }

    @Test("Error is Equatable")
    func errorIsEquatable() throws {
        let path = File.Path("/test")
        let error1 = File.Directory.Iterator.Error.pathNotFound(path)
        let error2 = File.Directory.Iterator.Error.pathNotFound(path)
        let error3 = File.Directory.Iterator.Error.permissionDenied(path)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

// MARK: - Edge Cases

extension File.Directory.Iterator.Test.EdgeCase {
    @Test("open on non-existent directory throws pathNotFound")
    func openNonExistentDirectory() throws {
        let directory = try File.Directory("/nonexistent-dir-\(Int.random(in: 0..<Int.max))")

        #expect(throws: File.Directory.Iterator.Error.self) {
            _ = try File.Directory.Iterator.open(at: directory)
        }
    }

    @Test("open on file throws notADirectory")
    func openOnFile() throws {
        try File.Directory.temporary { dir in
            // Create a file, not a directory
            let filePath = File.Path(dir.path, appending: "iter-file-test.txt")
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
            try handle.close()

            #expect(throws: File.Directory.Iterator.Error.self) {
                _ = try File.Directory.Iterator.open(at: File.Directory(filePath))
            }
        }
    }
}
