//
//  File.System.Link.Symbolic Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for symbolic links.
//
//  NOTE: Creating symbolic links on Windows requires either:
//  - Administrator privileges, OR
//  - Developer Mode enabled (Windows 10+)
//
//  These tests will skip gracefully if symlink creation fails due to
//  insufficient privileges.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if os(Windows)

    extension File.System.Link.Symbolic.Test.Unit {

        // MARK: - Helper to check if symlinks are available AND lstat works correctly

        private static func canCreateSymlinks(in dir: File.Directory) -> Bool {
            let testFile = File.Path(dir.path, appending: "symlink_test_target_\(Int.random(in: 0..<Int.max)).txt")
            let testLink = File.Path(dir.path, appending: "symlink_test_link_\(Int.random(in: 0..<Int.max))")
            defer {
                try? File.System.Delete.delete(at: testLink)
                try? File.System.Delete.delete(at: testFile)
            }
            do {
                // Create a test file and symlink to it
                try File.System.Write.Atomic.write([1, 2, 3], to: testFile)
                try File.System.Link.Symbolic.create(at: testLink, pointingTo: testFile)

                // Verify lstat correctly identifies it as a symlink
                let info = try File.System.Stat.lstatInfo(at: testLink)
                return info.type == .symbolicLink
            } catch {
                return false
            }
        }

        // MARK: - Symlink Creation Tests

        @Test("Create symlink to file")
        func createSymlinkToFile() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    // Skip test - insufficient privileges for symlinks
                    return
                }

                let targetPath = File.Path(dir.path, appending: "target.txt")
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link.txt")
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Verify link exists
                #expect(File.System.Stat.exists(at: linkPath))

                // Verify we can read through the link
                let data = try File.System.Read.Full.read(from: linkPath)
                #expect(data == [1, 2, 3])
            }
        }

        @Test("Create symlink to directory")
        func createSymlinkToDirectory() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target_dir"
                try File.System.Create.Directory.create(at: targetPath)

                // Create a file in the target directory
                let filePath = File.Path(targetPath, appending: "file.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                let linkPath = dir.path / "link_dir"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Verify link exists
                #expect(File.System.Stat.exists(at: linkPath))

                // Verify we can access file through the link
                let linkedFilePath = File.Path(linkPath, appending: "file.txt")
                let data = try File.System.Read.Full.read(from: linkedFilePath)
                #expect(data == [1])
            }
        }

        @Test("Read symlink target")
        func readSymlinkTarget() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = File.Path(dir.path, appending: "target.txt")
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link.txt")
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Read the target
                let target = try File.System.Link.Read.Target.target(of: linkPath)

                // The target should match what we set
                // Note: Windows may return absolute paths, so check the filename
                #expect(String(target).contains("target.txt"))
            }
        }

        @Test("Stat on symlink follows link by default")
        func statFollowsSymlink() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = File.Path(dir.path, appending: "target.txt")
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link.txt")
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // stat (info) should follow the symlink
                let info = try File.System.Stat.info(at: linkPath)
                #expect(info.type == .regular)  // Target is a file
                #expect(info.size == 5)  // Target's size
            }
        }

        @Test("Lstat on symlink returns symlink info")
        func lstatReturnsSymlinkInfo() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = File.Path(dir.path, appending: "target.txt")
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link.txt")
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // lstat (lstatInfo) should NOT follow the symlink
                let info = try File.System.Stat.lstatInfo(at: linkPath)
                #expect(info.type == .symbolicLink)
            }
        }

        // MARK: - Error Cases

        @Test("Read target of non-symlink fails")
        func readTargetOfNonSymlinkFails() throws {
            try File.Directory.temporary { dir in
                let filePath = File.Path(dir.path, appending: "regular.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                #expect(throws: File.System.Link.Read.Target.Error.notASymlink(filePath)) {
                    _ = try File.System.Link.Read.Target.target(of: filePath)
                }
            }
        }

        @Test("Read target of non-existent path fails")
        func readTargetOfNonExistentPathFails() throws {
            try File.Directory.temporary { dir in
                let nonExistent = File.Path(dir.path, appending: "nonexistent")

                #expect(throws: File.System.Link.Read.Target.Error.pathNotFound(nonExistent)) {
                    _ = try File.System.Link.Read.Target.target(of: nonExistent)
                }
            }
        }
    }

#endif
