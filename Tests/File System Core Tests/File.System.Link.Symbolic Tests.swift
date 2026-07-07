//
//  File.System.Link.Symbolic Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Link.Symbolic {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)

    extension File.System.Link.Symbolic.Test.Unit {

        // MARK: - Create Symlink

        @Test
        func `Create symlink to file`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.bin"
                try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                let linkPath = dir.path / "link"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Verify symlink exists
                #expect(File.System.Stat.exists(at: linkPath))

                // Verify it's a symlink using info(followSymlinks: false)
                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }

        @Test
        func `Create symlink to directory`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target-dir"
                try File.System.Create.Directory.create(at: targetPath)

                let linkPath = dir.path / "link"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }

        @Test
        func `Symlink points to correct target`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.bin"
                try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                let linkPath = dir.path / "link"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                // Read through symlink
                let data = try File.System.Read.Full.read(from: linkPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(data == [10, 20, 30])
            }
        }

        @Test
        func `Create symlink to non-existent target succeeds`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "non-existent-target"
                let linkPath = dir.path / "link"

                // Creating symlink to non-existent target should succeed
                // (it's a dangling symlink, but that's allowed)
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }

        // MARK: - Error Cases

        @Test
        func `Create symlink at existing path throws error with isAlreadyExists`() throws {
            try File.Directory.temporary { dir in
                let targetPath = dir.path / "target.bin"
                try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                let linkPath = dir.path / "existing.bin"
                try File.System.Write.Atomic.write([4, 5, 6].span, to: linkPath)

                do {
                    try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)
                    Issue.record("Expected error for existing path")
                } catch let error as File.System.Link.Symbolic.Error {
                    #expect(error.isAlreadyExists)
                }
            }
        }

        // MARK: - Semantic Accessors

        @Test
        func `isAlreadyExists semantic accessor`() {
            let error = File.System.Link.Symbolic.Error.symlink(.exists)
            #expect(error.isAlreadyExists)
            #expect(!error.isPermissionDenied)
        }

        @Test
        func `isPermissionDenied semantic accessor`() {
            let error = File.System.Link.Symbolic.Error.symlink(.permission)
            #expect(error.isPermissionDenied)
            #expect(!error.isAlreadyExists)
        }

        @Test
        func `isParentNotFound semantic accessor`() {
            let error = File.System.Link.Symbolic.Error.symlink(.notFound)
            #expect(error.isParentNotFound)
            #expect(!error.isAlreadyExists)
        }

        @Test
        func `isReadOnly semantic accessor`() {
            let error = File.System.Link.Symbolic.Error.symlink(.readOnly)
            #expect(error.isReadOnly)
            #expect(!error.isAlreadyExists)
        }

        @Test
        // swiftlint:disable:next swift_error_qualification - backtick test description, not a type reference
        func `Error description contains failure message`() {
            let error = File.System.Link.Symbolic.Error.symlink(.exists)
            #expect(error.description.contains("Symlink creation failed"))
        }
    }
#endif
