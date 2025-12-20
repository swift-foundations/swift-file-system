//
//  File.Directory.Walk Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Walk {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Walk.Test.Unit {
    private func createTempDir() throws -> File.Path {
        let path = try File.Path("/tmp/walk-test-\(Int.random(in: 0..<Int.max))")
        try File.System.Create.Directory.create(at: path)
        return path
    }

    private func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }

    @Test("walk empty directory returns empty array")
    func walkEmptyDirectory() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        let entries = try File.Directory.Walk.walk(at: dir)
        #expect(entries.isEmpty)
    }

    @Test("walk returns entries for non-empty directory")
    func walkNonEmptyDirectory() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        // Create files
        let file1 = File.Path(dir, appending: "file1.txt")
        let file2 = File.Path(dir, appending: "file2.txt")
        var h1 = try File.Handle.open(file1, mode: .write, options: [.create, .closeOnExec])
        try h1.close()
        var h2 = try File.Handle.open(file2, mode: .write, options: [.create, .closeOnExec])
        try h2.close()

        let entries = try File.Directory.Walk.walk(at: dir)
        #expect(entries.count == 2)

        let names = entries.compactMap { String($0.name) }.sorted()
        #expect(names == ["file1.txt", "file2.txt"])
    }

    @Test("walk recurses into subdirectories")
    func walkRecursesIntoSubdirectories() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        // Create subdir with file
        let subdir = File.Path(dir, appending: "subdir")
        try File.System.Create.Directory.create(at: subdir)

        let file = File.Path(subdir, appending: "nested.txt")
        var h = try File.Handle.open(file, mode: .write, options: [.create, .closeOnExec])
        try h.close()

        let entries = try File.Directory.Walk.walk(at: dir)
        #expect(entries.count == 2) // subdir + nested.txt

        let names = entries.compactMap { String($0.name) }.sorted()
        #expect(names.contains("subdir"))
        #expect(names.contains("nested.txt"))
    }

    @Test("Options.maxDepth limits recursion")
    func optionsMaxDepthLimitsRecursion() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        // Create nested structure: dir/a/b/c.txt
        let a = File.Path(dir, appending: "a")
        let b = File.Path(a, appending: "b")
        try File.System.Create.Directory.create(at: a)
        try File.System.Create.Directory.create(at: b)

        let c = File.Path(b, appending: "c.txt")
        var h = try File.Handle.open(c, mode: .write, options: [.create, .closeOnExec])
        try h.close()

        // maxDepth: 0 should only return immediate children
        let entries0 = try File.Directory.Walk.walk(at: dir, options: .init(maxDepth: 0))
        #expect(entries0.count == 1)
        #expect(String(entries0[0].name) == "a")

        // maxDepth: 1 should return dir/a and dir/a/b
        let entries1 = try File.Directory.Walk.walk(at: dir, options: .init(maxDepth: 1))
        #expect(entries1.count == 2)
    }

    @Test("Options.includeHidden filters hidden files")
    func optionsIncludeHiddenFilters() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }

        // Create visible and hidden files
        let visible = File.Path(dir, appending: "visible.txt")
        let hidden = File.Path(dir, appending: ".hidden")
        var h1 = try File.Handle.open(visible, mode: .write, options: [.create, .closeOnExec])
        try h1.close()
        var h2 = try File.Handle.open(hidden, mode: .write, options: [.create, .closeOnExec])
        try h2.close()

        // includeHidden: true (default)
        let entriesWithHidden = try File.Directory.Walk.walk(at: dir, options: .init(includeHidden: true))
        #expect(entriesWithHidden.count == 2)

        // includeHidden: false
        let entriesWithoutHidden = try File.Directory.Walk.walk(at: dir, options: .init(includeHidden: false))
        #expect(entriesWithoutHidden.count == 1)
        #expect(String(entriesWithoutHidden[0].name) == "visible.txt")
    }

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.Directory.Walk.Options()
        #expect(options.maxDepth == nil)
        #expect(options.followSymlinks == false)
        #expect(options.includeHidden == true)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
        let options = File.Directory.Walk.Options(
            maxDepth: 5,
            followSymlinks: true,
            includeHidden: false
        )
        #expect(options.maxDepth == 5)
        #expect(options.followSymlinks == true)
        #expect(options.includeHidden == false)
    }
}

// MARK: - Error Tests

extension File.Directory.Walk.Test.Unit {
    @Test("Error.pathNotFound description")
    func errorPathNotFoundDescription() throws {
        let path = try File.Path("/nonexistent")
        let error = File.Directory.Walk.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("Error.permissionDenied description")
    func errorPermissionDeniedDescription() throws {
        let path = try File.Path("/protected")
        let error = File.Directory.Walk.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("Error.notADirectory description")
    func errorNotADirectoryDescription() throws {
        let path = try File.Path("/tmp/file.txt")
        let error = File.Directory.Walk.Error.notADirectory(path)
        #expect(error.description.contains("Not a directory"))
    }

    @Test("Error.walkFailed description")
    func errorWalkFailedDescription() {
        let error = File.Directory.Walk.Error.walkFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Walk failed"))
        #expect(error.description.contains("I/O error"))
    }

    @Test("Error is Equatable")
    func errorIsEquatable() throws {
        let path = try File.Path("/test")
        let error1 = File.Directory.Walk.Error.pathNotFound(path)
        let error2 = File.Directory.Walk.Error.pathNotFound(path)
        let error3 = File.Directory.Walk.Error.permissionDenied(path)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

// MARK: - Edge Cases

extension File.Directory.Walk.Test.EdgeCase {
    @Test("walk on non-existent directory throws")
    func walkNonExistentDirectory() throws {
        let path = try File.Path("/nonexistent-\(Int.random(in: 0..<Int.max))")

        #expect(throws: File.Directory.Walk.Error.self) {
            _ = try File.Directory.Walk.walk(at: path)
        }
    }

    @Test("walk on file throws notADirectory")
    func walkOnFile() throws {
        let filePath = try File.Path("/tmp/walk-file-test-\(Int.random(in: 0..<Int.max))")
        defer { try? File.System.Delete.delete(at: filePath) }

        var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
        try handle.close()

        #expect(throws: File.Directory.Walk.Error.self) {
            _ = try File.Directory.Walk.walk(at: filePath)
        }
    }
}
