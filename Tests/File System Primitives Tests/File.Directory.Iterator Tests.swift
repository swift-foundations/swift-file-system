//
//  File.Directory.Iterator Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Iterator {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Iterator.Test.Unit {
    private func createTempDir() throws -> File.Path {
        let path = try File.Path("/tmp/iter-test-\(Int.random(in: 0..<Int.max))")
        try File.System.Create.Directory.create(at: path)
        return path
    }

    private func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }

    @Test("open on valid directory succeeds")
    func openValidDirectory() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        let iterator = try File.Directory.Iterator.open(at: dir)
        iterator.close()
    }

    @Test("next returns nil for empty directory")
    func nextReturnsNilForEmptyDirectory() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        var iterator = try File.Directory.Iterator.open(at: dir)
        let entry = try iterator.next()
        iterator.close()

        #expect(entry == nil)
    }

    @Test("next returns entries for non-empty directory")
    func nextReturnsEntriesForNonEmptyDirectory() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        // Create a file in the directory
        let filePath = File.Path(dir, appending: "testfile.txt")
        let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
        try handle.close()

        var iterator = try File.Directory.Iterator.open(at: dir)
        let entry = try iterator.next()
        iterator.close()

        #expect(entry != nil)
        #expect(entry.flatMap { String($0.name) } == "testfile.txt")
        #expect(entry?.type == .file)
    }

    @Test("iterator skips . and .. entries")
    func iteratorSkipsDotEntries() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

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

    @Test("close is idempotent")
    func closeIsIdempotent() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        let iterator = try File.Directory.Iterator.open(at: dir)
        iterator.close()
        // close() is consuming, so this is the only call
    }
}

// MARK: - Error Tests

extension File.Directory.Iterator.Test.Unit {
    @Test("Error.pathNotFound description")
    func errorPathNotFoundDescription() throws {
        let path = try File.Path("/nonexistent")
        let error = File.Directory.Iterator.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
        #expect(error.description.contains("/nonexistent"))
    }

    @Test("Error.permissionDenied description")
    func errorPermissionDeniedDescription() throws {
        let path = try File.Path("/protected")
        let error = File.Directory.Iterator.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("Error.notADirectory description")
    func errorNotADirectoryDescription() throws {
        let path = try File.Path("/tmp/file.txt")
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
        let path = try File.Path("/test")
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
        let path = try File.Path("/nonexistent-dir-\(Int.random(in: 0..<Int.max))")

        #expect(throws: File.Directory.Iterator.Error.self) {
            _ = try File.Directory.Iterator.open(at: path)
        }
    }

    @Test("open on file throws notADirectory")
    func openOnFile() throws {
        let filePath = try File.Path("/tmp/iter-file-test-\(Int.random(in: 0..<Int.max))")
        defer { try? File.System.Delete.delete(at: filePath) }

        // Create a file, not a directory
        let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
        try handle.close()

        #expect(throws: File.Directory.Iterator.Error.self) {
            _ = try File.Directory.Iterator.open(at: filePath)
        }
    }
}
