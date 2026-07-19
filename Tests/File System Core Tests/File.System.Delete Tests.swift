//
//  File.System.Delete Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Delete {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Delete.Test.Unit {

    // MARK: - Delete file

    @Test
    func `Delete existing file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: filePath))
        }
    }

    @Test
    func `Delete non-existing file throws pathNotFound`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "non-existing.txt"

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: filePath)
            }
        }
    }

    // MARK: - Delete directory

    @Test
    func `Delete empty directory`() throws {
        try File.Directory.temporary { dir in
            let subdir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subdir)

            try File.System.Delete.delete(at: subdir)

            #expect(!File.System.Stat.exists(at: subdir))
        }
    }

    @Test
    func `Delete non-empty directory without recursive throws`() throws {
        try File.Directory.temporary { dir in
            let subdir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subdir)
            try File.System.Write.Atomic.write(Array("content".utf8), to: subdir / "file.txt")

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: subdir)
            }

            // Directory should still exist
            #expect(File.System.Stat.exists(at: subdir))
        }
    }

    @Test
    func `Delete non-empty directory with recursive option`() throws {
        try File.Directory.temporary { dir in
            // Create nested structure
            let nested = dir.path / "a" / "b" / "c"
            try File.System.Create.Directory.create(at: nested, createIntermediates: true)
            try File.System.Write.Atomic.write(Array("file1".utf8), to: dir.path / "a" / "file1.txt")
            try File.System.Write.Atomic.write(Array("file2".utf8), to: dir.path / "a" / "b" / "file2.txt")

            let targetDir = dir.path / "a"
            try File.System.Delete.delete(at: targetDir, recursive: true)

            #expect(!File.System.Stat.exists(at: targetDir))
        }
    }

    // MARK: - Options

    @Test
    func `Options default values`() {
        let _ = File.System.Delete.Options()
    }

    // MARK: - Additional variants

    @Test
    func `Delete file variant`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "variant.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: filePath))
        }
    }

    @Test
    func `Delete directory with options variant`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "nested" / "deep"
            try File.System.Create.Directory.create(at: nested, createIntermediates: true)
            try File.System.Write.Atomic.write(Array("content".utf8), to: dir.path / "nested" / "file.txt")

            let targetDir = dir.path / "nested"
            try File.System.Delete.delete(at: targetDir, recursive: true)

            #expect(!File.System.Stat.exists(at: targetDir))
        }
    }

    // MARK: - Semantic accessors

    @Test
    func `isNotFound semantic accessor`() throws {
        try File.Directory.temporary { dir in
            let missingPath = dir.path / "non-existing.txt"

            do throws(File.System.Delete.Error) {
                try File.System.Delete.delete(at: missingPath)
                Issue.record("Expected error for non-existing path")
            } catch {
                #expect(error.isNotFound)
                #expect(!error.isPermissionDenied)
            }
        }
    }

    @Test
    func `isDirectoryNotEmpty semantic accessor`() throws {
        try File.Directory.temporary { dir in
            let subdir = dir.path / "nonempty"
            try File.System.Create.Directory.create(at: subdir)
            try File.System.Write.Atomic.write(Array("content".utf8), to: subdir / "file.txt")

            do throws(File.System.Delete.Error) {
                try File.System.Delete.delete(at: subdir)
                Issue.record("Expected error for non-empty directory")
            } catch {
                #expect(error.isDirectoryNotEmpty)
            }
        }
    }

    @Test
    func `isDirectory semantic accessor`() {
        // Test the semantic accessor on a manually constructed error
        let error = File.System.Delete.Error.unlink(.isDirectory)
        #expect(error.isDirectory)
        #expect(!error.isNotFound)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Delete.Error.unlink(.permission)
        #expect(error.isPermissionDenied)
        #expect(!error.isNotFound)
    }
}

// MARK: - Symlink Semantics (F-002)

extension File.System.Delete.Test.`Edge Case` {
    // Windows symlink creation requires Developer Mode or admin privileges
    // CI runners typically don't have — see File.System.Stat Tests.swift.
    #if !os(Windows)
        @Test
        func `Delete symlink to directory leaves target contents intact`() throws {
            try File.Directory.temporary { dir in
                let targetDir = dir.path / "target"
                try File.System.Create.Directory.create(at: targetDir)
                let targetFile = targetDir / "keep-me.txt"
                try File.System.Write.Atomic.write(Array("preserved".utf8).map(Byte.init), to: targetFile)

                let linkPath = dir.path / "link-to-target"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetDir)

                try File.System.Delete.delete(at: linkPath, recursive: true)

                // The link itself is gone…
                #expect(!File.System.Stat.exists(at: linkPath))
                // …but the target directory and its contents are untouched.
                #expect(File.System.Stat.exists(at: targetDir))
                #expect(File.System.Stat.exists(at: targetFile))
            }
        }

        @Test
        func `Delete symlink to directory without recursive also leaves target intact`() throws {
            try File.Directory.temporary { dir in
                let targetDir = dir.path / "target"
                try File.System.Create.Directory.create(at: targetDir)
                let targetFile = targetDir / "keep-me.txt"
                try File.System.Write.Atomic.write(Array("preserved".utf8).map(Byte.init), to: targetFile)

                let linkPath = dir.path / "link-to-target"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetDir)

                try File.System.Delete.delete(at: linkPath)

                #expect(!File.System.Stat.exists(at: linkPath))
                #expect(File.System.Stat.exists(at: targetDir))
                #expect(File.System.Stat.exists(at: targetFile))
            }
        }

        @Test
        func `Delete dangling symlink succeeds`() throws {
            try File.Directory.temporary { dir in
                let missingTarget = dir.path / "does-not-exist"
                let linkPath = dir.path / "dangling-link"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: missingTarget)

                try File.System.Delete.delete(at: linkPath)

                #expect(!File.System.Stat.exists(at: linkPath))
            }
        }

        @Test
        func `Recursive delete of tree containing symlinks removes links not targets`() throws {
            try File.Directory.temporary { dir in
                let targetDir = dir.path / "outside-target"
                try File.System.Create.Directory.create(at: targetDir)
                let targetFile = targetDir / "keep-me.txt"
                try File.System.Write.Atomic.write(Array("preserved".utf8).map(Byte.init), to: targetFile)

                let tree = dir.path / "tree"
                try File.System.Create.Directory.create(at: tree)
                try File.System.Write.Atomic.write(Array("data".utf8).map(Byte.init), to: tree / "file.txt")

                let linkInTree = tree / "link-to-outside"
                try File.System.Link.Symbolic.create(at: linkInTree, pointingTo: targetDir)

                try File.System.Delete.delete(at: tree, recursive: true)

                // The whole tree (including the symlink entry) is gone…
                #expect(!File.System.Stat.exists(at: tree))
                // …but the linked-to directory outside the tree survives.
                #expect(File.System.Stat.exists(at: targetDir))
                #expect(File.System.Stat.exists(at: targetFile))
            }
        }
    #endif
}
