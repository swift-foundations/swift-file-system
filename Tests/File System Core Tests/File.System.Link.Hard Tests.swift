//
//  File.System.Link.Hard Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Link.Hard {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)

    extension File.System.Link.Hard.Test.Unit {

        // MARK: - Create Hard Link

        @Test
        func `Create hard link to file`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "source.bin"
                let linkPath = dir.path / "link.bin"

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                #expect(File.System.Stat.exists(at: linkPath))

                // Both files should have same content
                let existingData = try File.System.Read.Full.read(from: existingPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                let linkData = try File.System.Read.Full.read(from: linkPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(existingData == linkData)
            }
        }

        @Test
        func `Hard link shares inode with original`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "source.bin"
                let linkPath = dir.path / "link.bin"

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Get inode numbers using our stat API
                let existingInfo = try File.System.Stat.info(at: existingPath)
                let linkInfo = try File.System.Stat.info(at: linkPath)

                #expect(existingInfo.inode == linkInfo.inode)
            }
        }

        @Test
        func `Modifying hard link modifies original`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "source.bin"
                let linkPath = dir.path / "link.bin"

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Modify through the link using in-place write (not atomic write which replaces the file)
                var handle = try File.Handle.open(linkPath, mode: .write, options: [.truncate])
                try handle.write([10, 20, 30].span)
                try handle.close()

                // Original should also be modified (same inode)
                let originalData = try File.System.Read.Full.read(from: existingPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(originalData == [10, 20, 30])
            }
        }

        @Test
        func `Deleting original does not delete hard link`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "source.bin"
                let linkPath = dir.path / "link.bin"

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Delete original
                try File.System.Delete.delete(at: existingPath)

                // Hard link should still exist and have the data
                #expect(File.System.Stat.exists(at: linkPath))
                let data = try File.System.Read.Full.read(from: linkPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(data == [1, 2, 3])
            }
        }

        // MARK: - Error Cases

        @Test
        func `Create hard link to non-existent file throws error with isSourceNotFound`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "non-existent.bin"
                let linkPath = dir.path / "link.bin"

                do {
                    try File.System.Link.Hard.create(at: linkPath, to: existingPath)
                    Issue.record("Expected error for non-existent source")
                } catch let error as File.System.Link.Hard.Error {
                    #expect(error.isSourceNotFound)
                }
            }
        }

        @Test
        func `Create hard link at existing path throws error with isAlreadyExists`() throws {
            try File.Directory.temporary { dir in
                let existingPath = dir.path / "source.bin"
                let linkPath = dir.path / "link.bin"

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)
                try File.System.Write.Atomic.write([4, 5, 6].span, to: linkPath)

                do {
                    try File.System.Link.Hard.create(at: linkPath, to: existingPath)
                    Issue.record("Expected error for existing path")
                } catch let error as File.System.Link.Hard.Error {
                    #expect(error.isAlreadyExists)
                }
            }
        }

        // MARK: - Semantic Accessors

        @Test
        func `isSourceNotFound semantic accessor`() {
            let error = File.System.Link.Hard.Error.link(.notFound)
            #expect(error.isSourceNotFound)
            #expect(!error.isAlreadyExists)
            #expect(!error.isPermissionDenied)
        }

        @Test
        func `isPermissionDenied semantic accessor`() {
            let error = File.System.Link.Hard.Error.link(.permission)
            #expect(error.isPermissionDenied)
            #expect(!error.isSourceNotFound)
        }

        @Test
        func `isAlreadyExists semantic accessor`() {
            let error = File.System.Link.Hard.Error.link(.exists)
            #expect(error.isAlreadyExists)
            #expect(!error.isSourceNotFound)
        }

        @Test
        func `isCrossDevice semantic accessor`() {
            let error = File.System.Link.Hard.Error.link(.crossDevice)
            #expect(error.isCrossDevice)
            #expect(!error.isSourceNotFound)
        }

        @Test
        func `isDirectory semantic accessor`() {
            let error = File.System.Link.Hard.Error.link(.isDirectory)
            #expect(error.isDirectory)
            #expect(!error.isSourceNotFound)
        }

        @Test
        func `Error description contains failure message`() {
            let error = File.System.Link.Hard.Error.link(.notFound)
            #expect(error.description.contains("Hard link creation failed"))
        }
    }
#endif
