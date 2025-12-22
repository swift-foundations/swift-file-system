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
        let h1 = try File.Handle.open(file1, mode: .write, options: [.create, .closeOnExec])
        try h1.close()
        let h2 = try File.Handle.open(file2, mode: .write, options: [.create, .closeOnExec])
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
        let h = try File.Handle.open(file, mode: .write, options: [.create, .closeOnExec])
        try h.close()

        let entries = try File.Directory.Walk.walk(at: dir)
        #expect(entries.count == 2)  // subdir + nested.txt

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
        let h = try File.Handle.open(c, mode: .write, options: [.create, .closeOnExec])
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
        let h1 = try File.Handle.open(visible, mode: .write, options: [.create, .closeOnExec])
        try h1.close()
        let h2 = try File.Handle.open(hidden, mode: .write, options: [.create, .closeOnExec])
        try h2.close()

        // includeHidden: true (default)
        let entriesWithHidden = try File.Directory.Walk.walk(
            at: dir,
            options: .init(includeHidden: true)
        )
        #expect(entriesWithHidden.count == 2)

        // includeHidden: false
        let entriesWithoutHidden = try File.Directory.Walk.walk(
            at: dir,
            options: .init(includeHidden: false)
        )
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

    // MARK: - onUndecodable Callback Tests

    @Test("Options default onUndecodable returns skip")
    func optionsDefaultOnUndecodable() throws {
        let options = File.Directory.Walk.Options()
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )
        let policy = options.onUndecodable(context)
        switch policy {
        case .skip:
            #expect(true)
        default:
            Issue.record("Expected default policy to be .skip")
        }
    }

    @Test("Options custom onUndecodable callback returns custom policy")
    func optionsCustomOnUndecodable() throws {
        let options = File.Directory.Walk.Options(
            onUndecodable: { _ in .emit }
        )
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )
        let policy = options.onUndecodable(context)
        switch policy {
        case .emit:
            #expect(true)
        default:
            Issue.record("Expected policy to be .emit")
        }
    }

    @Test("Options onUndecodable can return stopAndThrow")
    func optionsOnUndecodableStopAndThrow() throws {
        let options = File.Directory.Walk.Options(
            onUndecodable: { _ in .stopAndThrow }
        )
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .directory,
            depth: 2
        )
        let policy = options.onUndecodable(context)
        switch policy {
        case .stopAndThrow:
            #expect(true)
        default:
            Issue.record("Expected policy to be .stopAndThrow")
        }
    }

    @Test("Options onUndecodable callback receives context properties")
    func optionsOnUndecodableContext() throws {
        // Test that the callback can access context properties
        // by returning different policies based on context
        let options = File.Directory.Walk.Options(
            onUndecodable: { context in
                // Callback can read all context properties
                if context.depth > 2 && context.type == .directory {
                    return .stopAndThrow
                }
                return .skip
            }
        )

        // Test with shallow file - should skip
        let shallowFile = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 1
        )
        switch options.onUndecodable(shallowFile) {
        case .skip:
            #expect(true)
        default:
            Issue.record("Expected skip for shallow file")
        }

        // Test with deep directory - should stopAndThrow
        let deepDir = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/a/b/c"),
            name: File.Name(rawBytes: [0x80]),
            type: .directory,
            depth: 3
        )
        switch options.onUndecodable(deepDir) {
        case .stopAndThrow:
            #expect(true)
        default:
            Issue.record("Expected stopAndThrow for deep directory")
        }
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

    @Test("Error.undecodableEntry description")
    func errorUndecodableEntryDescription() throws {
        let parent = try File.Path("/test/dir")
        let name = File.Name(rawBytes: [0x80, 0x81])
        let error = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)
        #expect(error.description.contains("Undecodable entry"))
        #expect(error.description.contains("/test/dir"))
    }

    @Test("Error.undecodableEntry is Equatable")
    func errorUndecodableEntryEquatable() throws {
        let parent = try File.Path("/test")
        let name = File.Name(rawBytes: [0x80])

        let error1 = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)
        let error2 = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)

        #expect(error1 == error2)
    }

    @Test("Error is Sendable")
    func errorIsSendable() async throws {
        let path = try File.Path("/test")
        let error = File.Directory.Walk.Error.pathNotFound(path)

        let result = await Task {
            error
        }.value

        #expect(result == error)
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

        let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
        try handle.close()

        #expect(throws: File.Directory.Walk.Error.self) {
            _ = try File.Directory.Walk.walk(at: filePath)
        }
    }
}
