//
//  File.Directory.Walk Tests.swift
//  swift-file-system

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Walk {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)
    // MARK: - Unit Tests

    extension File.Directory.Walk.Test.Unit {
        @Test
        func `walk empty directory returns empty array`() throws {
            try File.Directory.temporary { dir in
                let entries = try dir.walk()
                #expect(entries.isEmpty)
            }
        }

        @Test
        func `walk returns entries for non-empty directory`() throws {
            try File.Directory.temporary { dir in
                // Create files
                let file1 = dir.path / "file1.txt"
                let file2 = dir.path / "file2.txt"
                let h1 = try File.Handle.open(file1, mode: .write, options: [.create, .execClose])
                try h1.close()
                let h2 = try File.Handle.open(file2, mode: .write, options: [.create, .execClose])
                try h2.close()

                let entries = try dir.walk()
                #expect(entries.count == 2)

                let names = entries.compactMap { Swift.String($0.name) }.sorted()
                #expect(names == ["file1.txt", "file2.txt"])
            }
        }

        @Test
        func `walk recurses into subdirectories`() throws {
            try File.Directory.temporary { dir in
                // Create subdir with file
                let subdir = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subdir)

                let file = subdir / "nested.txt"
                let h = try File.Handle.open(file, mode: .write, options: [.create, .execClose])
                try h.close()

                let entries = try dir.walk()
                #expect(entries.count == 2)  // subdir + nested.txt

                let names = entries.compactMap { Swift.String($0.name) }.sorted()
                #expect(names.contains("subdir"))
                #expect(names.contains("nested.txt"))
            }
        }

        @Test
        func `Options.maxDepth limits recursion`() throws {
            try File.Directory.temporary { dir in
                // Create nested structure: dir/a/b/c.txt
                let a = dir.path / "a"
                let b = a / "b"
                try File.System.Create.Directory.create(at: a)
                try File.System.Create.Directory.create(at: b)

                let c = b / "c.txt"
                let h = try File.Handle.open(c, mode: .write, options: [.create, .execClose])
                try h.close()

                // maxDepth: 0 should only return immediate children
                let entries0 = try dir.walk(options: .init(maxDepth: 0))
                #expect(entries0.count == 1)
                #expect(Swift.String(entries0[0].name) == "a")

                // maxDepth: 1 should return dir/a and dir/a/b
                let entries1 = try dir.walk(options: .init(maxDepth: 1))
                #expect(entries1.count == 2)
            }
        }

        @Test
        func `Options.includeHidden filters hidden files`() throws {
            try File.Directory.temporary { dir in
                // Create visible and hidden files
                let visible = dir.path / "visible.txt"
                let hidden = dir.path / ".hidden"
                let h1 = try File.Handle.open(visible, mode: .write, options: [.create, .execClose])
                try h1.close()
                let h2 = try File.Handle.open(hidden, mode: .write, options: [.create, .execClose])
                try h2.close()

                // includeHidden: true (default)
                let entriesWithHidden = try dir.walk(options: .init(includeHidden: true))
                #expect(entriesWithHidden.count == 2)

                // includeHidden: false
                let entriesWithoutHidden = try dir.walk(options: .init(includeHidden: false))
                #expect(entriesWithoutHidden.count == 1)
                #expect(Swift.String(entriesWithoutHidden[0].name) == "visible.txt")
            }
        }

        @Test
        func `Options default values`() {
            let options = File.Directory.Walk.Options()
            #expect(options.maxDepth == nil)
            #expect(options.followSymlinks == false)
            #expect(options.includeHidden == true)
        }

        @Test
        func `Options custom values`() {
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

        @Test
        func `Options default onUndecodable returns skip`() {
            let options = File.Directory.Walk.Options()
            let context = File.Directory.Walk.Undecodable.Context(
                parent: "/tmp",
                name: File.Name(rawBytes: [0x80]),
                type: .file,
                depth: 0
            )
            let policy = options.onUndecodable(context)
            switch policy {
            case .skip:
                #expect(Bool(true))

            default:
                Issue.record("Expected default policy to be .skip")
            }
        }

        @Test
        func `Options custom onUndecodable callback returns custom policy`() {
            let options = File.Directory.Walk.Options(
                onUndecodable: { _ in .emit }
            )
            let context = File.Directory.Walk.Undecodable.Context(
                parent: "/tmp",
                name: File.Name(rawBytes: [0x80]),
                type: .file,
                depth: 0
            )
            let policy = options.onUndecodable(context)
            switch policy {
            case .emit:
                #expect(Bool(true))

            default:
                Issue.record("Expected policy to be .emit")
            }
        }

        @Test
        func `Options onUndecodable can return stopAndThrow`() {
            let options = File.Directory.Walk.Options(
                onUndecodable: { _ in .stopAndThrow }
            )
            let context = File.Directory.Walk.Undecodable.Context(
                parent: "/tmp",
                name: File.Name(rawBytes: [0x80]),
                type: .directory,
                depth: 2
            )
            let policy = options.onUndecodable(context)
            switch policy {
            case .stopAndThrow:
                #expect(Bool(true))

            default:
                Issue.record("Expected policy to be .stopAndThrow")
            }
        }

        @Test
        func `Options onUndecodable callback receives context properties`() {
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
                parent: "/tmp",
                name: File.Name(rawBytes: [0x80]),
                type: .file,
                depth: 1
            )
            switch options.onUndecodable(shallowFile) {
            case .skip:
                #expect(Bool(true))

            default:
                Issue.record("Expected skip for shallow file")
            }

            // Test with deep directory - should stopAndThrow
            let deepDir = File.Directory.Walk.Undecodable.Context(
                parent: "/a/b/c",
                name: File.Name(rawBytes: [0x80]),
                type: .directory,
                depth: 3
            )
            switch options.onUndecodable(deepDir) {
            case .stopAndThrow:
                #expect(Bool(true))

            default:
                Issue.record("Expected stopAndThrow for deep directory")
            }
        }
    }

    // MARK: - Error Tests

    extension File.Directory.Walk.Test.Unit {
        @Test
        func `Error.pathNotFound description`() {
            let path: File.Path = "/nonexistent"
            let error = File.Directory.Walk.Error.pathNotFound(path)
            #expect(error.description.contains("Path not found"))
        }

        @Test
        func `Error.permissionDenied description`() {
            let path: File.Path = "/protected"
            let error = File.Directory.Walk.Error.permissionDenied(path)
            #expect(error.description.contains("Permission denied"))
        }

        @Test
        func `Error.notADirectory description`() {
            let path: File.Path = "/tmp/file.txt"
            let error = File.Directory.Walk.Error.notADirectory(path)
            #expect(error.description.contains("Not a directory"))
        }

        @Test
        func `Error.walkFailed description`() {
            let error = File.Directory.Walk.Error.walkFailed(errno: 5, message: "I/O error")
            #expect(error.description.contains("Walk failed"))
            #expect(error.description.contains("I/O error"))
        }

        @Test
        func `Error is Equatable`() {
            let path: File.Path = "/test"
            let error1 = File.Directory.Walk.Error.pathNotFound(path)
            let error2 = File.Directory.Walk.Error.pathNotFound(path)
            let error3 = File.Directory.Walk.Error.permissionDenied(path)

            #expect(error1 == error2)
            #expect(error1 != error3)
        }

        @Test
        func `Error.undecodableEntry description`() {
            let parent: File.Path = "/test/dir"
            let name = File.Name(rawBytes: [0x80, 0x81])
            let error = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)
            #expect(error.description.contains("Undecodable entry"))
            #expect(error.description.contains("/test/dir"))
        }

        @Test
        func `Error.undecodableEntry is Equatable`() {
            let parent: File.Path = "/test"
            let name = File.Name(rawBytes: [0x80])

            let error1 = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)
            let error2 = File.Directory.Walk.Error.undecodableEntry(parent: parent, name: name)

            #expect(error1 == error2)
        }

        @Test
        func `Error is Sendable`() async {
            let path: File.Path = "/test"
            let error = File.Directory.Walk.Error.pathNotFound(path)

            let result = await Task {
                error
            }.value

            #expect(result == error)
        }
    }

    // MARK: - Edge Cases

    extension File.Directory.Walk.Test.`Edge Case` {
        @Test
        func `walk on non-existent directory throws`() throws {
            let path = try File.Path("/nonexistent-\(Int.random(in: (0..<Int.max)))")
            let nonExistentDir = File.Directory(path)

            #expect(throws: File.Directory.Walk.Error.self) {
                _ = try nonExistentDir.walk()
            }
        }

        @Test
        func `walk on file throws notADirectory`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "testfile.txt"
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .execClose])
                try handle.close()

                let fileAsDir = File.Directory(filePath)
                #expect(throws: File.Directory.Walk.Error.self) {
                    _ = try fileAsDir.walk()
                }
            }
        }
    }
#endif
