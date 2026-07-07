//
//  File.System.Stat Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import File_System_Core

extension File.System.Stat {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Stat.Test.Unit {

    // MARK: - exists()

    @Test
    func `exists returns true for existing file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            #expect(File.System.Stat.exists(at: filePath) == true)
        }
    }

    @Test
    func `exists returns true for existing directory`() throws {
        try File.Directory.temporary { dir in
            let subDir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subDir)

            #expect(File.System.Stat.exists(at: subDir) == true)
        }
    }

    @Test
    func `exists returns false for non-existing path`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "non-existing"
            #expect(File.System.Stat.exists(at: filePath) == false)
        }
    }

    // MARK: - Type checks via info()

    @Test
    func `info returns regular type for file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            let info = try File.System.Stat.info(at: filePath)
            #expect(info.type == .regular)
        }
    }

    @Test
    func `info returns directory type for directory`() throws {
        try File.Directory.temporary { dir in
            let subDir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subDir)

            let info = try File.System.Stat.info(at: subDir)
            #expect(info.type == .directory)
        }
    }

    @Test
    func `info throws for non-existing path`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "non-existing"
            #expect(throws: Kernel.File.Stats.Error.self) {
                _ = try File.System.Stat.info(at: filePath)
            }
        }
    }

    // Note: Symlink tests are in platform-specific test files.
    // Windows symlink creation requires Developer Mode or admin privileges,
    // which CI runners typically don't have.
    #if !os(Windows)
        @Test
        func `info(followSymlinks: false) returns symbolicLink type for symlink`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.txt"
                let linkPath = dir.path / "link"

                try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: targetPath)
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }
    #endif

    @Test
    func `info(followSymlinks: false) returns regular type for file (not symlink)`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            let info = try File.System.Stat.info(at: filePath, followSymlinks: false)
            #expect(info.type == .regular)
        }
    }

    @Test
    func `info(followSymlinks: false) returns directory type for directory (not symlink)`() throws {
        try File.Directory.temporary { dir in
            let subDir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subDir)

            let info = try File.System.Stat.info(at: subDir, followSymlinks: false)
            #expect(info.type == .directory)
        }
    }

    // MARK: - info()

    @Test
    func `info returns correct type for file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("Hello, World!".utf8).map(Byte.init), to: filePath)

            let info = try File.System.Stat.info(at: filePath)

            #expect(info.type == .regular)
            #expect(info.size == 13)  // "Hello, World!" is 13 bytes
        }
    }

    @Test
    func `info returns correct type for directory`() throws {
        try File.Directory.temporary { dir in
            let subDir = dir.path / "subdir"
            try File.System.Create.Directory.create(at: subDir)

            let info = try File.System.Stat.info(at: subDir)
            #expect(info.type == .directory)
        }
    }

    #if !os(Windows)
        // Windows symlink behavior differs from POSIX - it may not follow symlinks the same way

        @Test
        func `info returns correct type for symlink`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.txt"
                let linkPath = dir.path / "link"

                try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: targetPath)
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath)

                // info() follows symlinks by default, so it should return the target type
                #expect(info.type == .regular)
            }
        }
    #endif

    // MARK: - Async variants

    @Test
    func `async exists works`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            let exists = File.System.Stat.exists(at: filePath)
            #expect(exists == true)
        }
    }

    @Test
    func `async info returns regular type for file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write(Array("test".utf8).map(Byte.init), to: filePath)

            let info = try File.System.Stat.info(at: filePath)
            #expect(info.type == .regular)
        }
    }

    // MARK: - info(followSymlinks: false) tests

    #if !os(Windows)
        // Windows symlink semantics differ from POSIX - stat/lstat may not distinguish the same way

        @Test
        func `info(followSymlinks: false) returns symbolicLink type for symlink (Handle API)`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.txt"
                let linkPath = dir.path / "link"

                // Create target file using our API
                var handle = try File.Handle.open(
                    targetPath,
                    mode: .write,
                    options: [.create, .execClose]
                )
                do {
                    let bytes: [Byte] = Array("test".utf8).map(Byte.init)
                    try handle.write(bytes.span)
                }
                try handle.close()

                // Create symlink using our API
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // info(followSymlinks: false) should return symbolicLink type (doesn't follow)
                let lstatInfo = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(lstatInfo.type == .symbolicLink)

                // info should return regular type (follows symlink)
                let statInfo = try File.System.Stat.info(at: linkPath)
                #expect(statInfo.type == .regular)
            }
        }

        @Test
        func `info(followSymlinks: false) returns different inode than info for symlink`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.txt"
                let linkPath = dir.path / "link"

                // Create target file using our API
                var handle = try File.Handle.open(
                    targetPath,
                    mode: .write,
                    options: [.create, .execClose]
                )
                do {
                    let bytes: [Byte] = Array("test".utf8).map(Byte.init)
                    try handle.write(bytes.span)
                }
                try handle.close()

                // Create symlink using our API
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // info(followSymlinks: false) returns the symlink's own inode
                let lstatInfo = try File.System.Stat.info(at: linkPath, followSymlinks: false)

                // info on symlink follows to target, should have same inode as target
                let statInfo = try File.System.Stat.info(at: linkPath)
                let targetInfo = try File.System.Stat.info(at: targetPath)

                // The symlink has its own inode, different from the target
                #expect(lstatInfo.inode != targetInfo.inode)

                // info() on symlink should return the target's inode
                #expect(statInfo.inode == targetInfo.inode)
            }
        }
    #endif

    @Test
    func `info(followSymlinks: false) same as info for regular file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "regular.txt"

            // Create file using our API
            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            do {
                let bytes: [Byte] = Array("test content".utf8).map(Byte.init)
                try handle.write(bytes.span)
            }
            try handle.close()

            let lstatInfo = try File.System.Stat.info(at: filePath, followSymlinks: false)
            let statInfo = try File.System.Stat.info(at: filePath)

            // For regular files, both should return the same info
            #expect(lstatInfo.type == statInfo.type)
            #expect(lstatInfo.inode == statInfo.inode)
            #expect(lstatInfo.size == statInfo.size)
        }
    }
}
