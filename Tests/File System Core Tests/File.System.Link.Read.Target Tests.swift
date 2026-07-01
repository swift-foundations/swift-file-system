//
//  File.System.Link.Read.Target Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Link.Read.Target {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Link.Read.Target.Test.Unit {
    // MARK: - Read Target

    #if !os(Windows)
        // Windows symlink target reading returns the link path instead of the actual target path
        // These tests require POSIX symlink semantics

        @Test
        func `Read target of symlink to file`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.bin"
                try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                let linkPath = dir.path / "link"
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(Swift.String(target) == Swift.String(targetPath))
            }
        }

        @Test
        func `Read target of symlink to directory`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target-dir"
                try File.System.Create.Directory.create(at: targetPath)

                let linkPath = dir.path / "link"
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(Swift.String(target) == Swift.String(targetPath))
            }
        }

        @Test
        func `Read target of dangling symlink`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "non-existent"
                let linkPath = dir.path / "link"

                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(Swift.String(target) == Swift.String(targetPath))
            }
        }

        @Test
        func `Read target of relative symlink`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: File.Path("target.txt")
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(Swift.String(target) == "target.txt")
            }
        }
    #endif

    // MARK: - Error Cases

    @Test
    func `Read target of regular file throws error with isNotASymlink`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "file.bin"
            try File.System.Write.Atomic.write([1, 2, 3].span, to: filePath)

            do {
                _ = try File.System.Link.Read.Target.target(of: filePath)
                Issue.record("Expected error for regular file")
            } catch let error as File.System.Link.Read.Target.Error {
                #expect(error.isNotASymlink)
            }
        }
    }

    @Test
    func `Read target of directory throws error with isNotASymlink`() throws {
        try File.Directory.temporary { dir in
            let dirPath = dir.path / "subdir"
            try File.System.Create.Directory.create(at: dirPath)

            do {
                _ = try File.System.Link.Read.Target.target(of: dirPath)
                Issue.record("Expected error for directory")
            } catch let error as File.System.Link.Read.Target.Error {
                #expect(error.isNotASymlink)
            }
        }
    }

    @Test
    func `Read target of non-existent path throws error with isNotFound`() throws {
        try File.Directory.temporary { dir in
            let nonExistent = dir.path / "non-existent"

            do {
                _ = try File.System.Link.Read.Target.target(of: nonExistent)
                Issue.record("Expected error for non-existent path")
            } catch let error as File.System.Link.Read.Target.Error {
                #expect(error.isNotFound)
            }
        }
    }

    // MARK: - Semantic Accessors

    @Test
    func `notASymlink error has correct description`() throws {
        let path = File.Path("/tmp/regular")
        let error = File.System.Link.Read.Target.Error.notASymlink(path)
        #expect(error.description.contains("Not a symbolic link"))
        #expect(error.isNotASymlink)
    }

    @Test
    func `isNotFound semantic accessor`() {
        let error = File.System.Link.Read.Target.Error.readlink(.notFound)
        #expect(error.isNotFound)
        #expect(!error.isNotASymlink)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Link.Read.Target.Error.readlink(.permission)
        #expect(error.isPermissionDenied)
        #expect(!error.isNotFound)
    }

    @Test
    func `isNotASymlink semantic accessor`() {
        let error = File.System.Link.Read.Target.Error.notASymlink(File.Path("/tmp/file"))
        #expect(error.isNotASymlink)
        #expect(!error.isNotFound)
    }

}
