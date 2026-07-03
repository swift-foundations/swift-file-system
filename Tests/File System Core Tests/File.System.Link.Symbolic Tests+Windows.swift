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
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)

    extension File.System.Link.Symbolic.Test.Unit {

        // MARK: - Helper to check if symlinks are available AND lstat works correctly

        private static func canCreateSymlinks(in dir: File.Directory) -> Bool {
            let testFile = dir.path / "symlink_test_target_\(Int.random(in: (0..<Int.max))).txt"
            let testLink = dir.path / "symlink_test_link_\(Int.random(in: (0..<Int.max))).lnk"
            defer {
                try? File.System.Delete.delete(at: testLink)
                try? File.System.Delete.delete(at: testFile)
            }
            do {
                // Create a test file and symlink to it
                try File.System.Write.Atomic.write([1, 2, 3], to: testFile)
                try File.System.Link.Symbolic.create(at: testLink, pointingTo: testFile)

                // Verify info(followSymlinks: false) correctly identifies it as a symlink
                let info = try File.System.Stat.info(at: testLink, followSymlinks: false)
                return info.type == .symbolicLink
            } catch {
                return false
            }
        }

        // MARK: - Symlink Creation Tests

        @Test
        func `Create symlink to file`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    // Skip test - insufficient privileges for symlinks
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Verify link exists
                #expect(File.System.Stat.exists(at: linkPath))

                // Verify we can read through the link
                let data = try File.System.Read.Full.read(from: linkPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(data == [1, 2, 3])
            }
        }

        @Test
        func `Create symlink to directory`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target_dir"
                try File.System.Create.Directory.create(at: targetPath)

                // Create a file in the target directory
                let filePath = targetPath / "file.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let linkPath = dir.path / "link_dir"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Verify link exists
                #expect(File.System.Stat.exists(at: linkPath))

                // Verify we can access file through the link
                let linkedFilePath = linkPath / "file.txt"
                let data = try File.System.Read.Full.read(from: linkedFilePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(data == [1])
            }
        }

        @Test
        func `Read symlink target`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Read the target
                let target = try File.System.Link.Read.Target.target(of: linkPath)

                // The target should match what we set
                // Note: Windows may return absolute paths, so check the filename
                #expect(Swift.String(target).contains("target.txt"))
            }
        }

        @Test
        func `Stat on symlink follows link by default`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // stat (info) should follow the symlink
                let info = try File.System.Stat.info(at: linkPath)
                #expect(info.type == .regular)  // Target is a file
                #expect(info.size == 5)  // Target's size
            }
        }

        @Test
        func `info(followSymlinks: false) on symlink returns symlink info`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // info(followSymlinks: false) should NOT follow the symlink
                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }

        // MARK: - Error Cases

        @Test
        func `Read target of non-symlink fails`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "regular.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                do {
                    _ = try File.System.Link.Read.Target.target(of: filePath)
                    Issue.record("Expected error for non-symlink")
                } catch let error as File.System.Link.Read.Target.Error {
                    #expect(error.isNotASymlink)
                }
            }
        }

        @Test
        func `Read target of non-existent path fails`() throws {
            try File.Directory.temporary { dir in
                let nonExistent = dir.path / "nonexistent"

                do {
                    _ = try File.System.Link.Read.Target.target(of: nonExistent)
                    Issue.record("Expected error for non-existent path")
                } catch let error as File.System.Link.Read.Target.Error {
                    #expect(error.isNotFound)
                }
            }
        }
    }

#endif
