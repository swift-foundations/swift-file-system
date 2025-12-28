//
//  File.System.Link.Hard Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Link.Hard {
    #TestSuites
}

#if os(macOS) || os(Linux)

    extension File.System.Link.Hard.Test.Unit {

        // MARK: - Create Hard Link

        @Test("Create hard link to file")
        func createHardLinkToFile() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "source.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                #expect(File.System.Stat.exists(at: linkPath))

                // Both files should have same content
                let existingData = try File.System.Read.Full.read(from: existingPath)
                let linkData = try File.System.Read.Full.read(from: linkPath)
                #expect(existingData == linkData)
            }
        }

        @Test("Hard link shares inode with original")
        func hardLinkSharesInode() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "source.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Get inode numbers using our stat API
                let existingInfo = try File.System.Stat.info(at: existingPath)
                let linkInfo = try File.System.Stat.info(at: linkPath)

                #expect(existingInfo.inode == linkInfo.inode)
            }
        }

        @Test("Modifying hard link modifies original")
        func modifyingHardLinkModifiesOriginal() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "source.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Modify through the link using in-place write (not atomic write which replaces the file)
                var handle = try File.Handle.open(linkPath, mode: .write, options: [.truncate])
                try handle.write([10, 20, 30].span)
                try handle.close()

                // Original should also be modified (same inode)
                let originalData = try File.System.Read.Full.read(from: existingPath)
                #expect(originalData == [10, 20, 30])
            }
        }

        @Test("Deleting original does not delete hard link")
        func deletingOriginalDoesNotDeleteHardLink() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "source.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)

                try File.System.Link.Hard.create(at: linkPath, to: existingPath)

                // Delete original
                try File.System.Delete.delete(at: existingPath)

                // Hard link should still exist and have the data
                #expect(File.System.Stat.exists(at: linkPath))
                let data = try File.System.Read.Full.read(from: linkPath)
                #expect(data == [1, 2, 3])
            }
        }

        // MARK: - Error Cases

        @Test("Create hard link to non-existent file throws sourceNotFound")
        func createHardLinkToNonExistentThrows() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "non-existent.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                #expect(throws: File.System.Link.Hard.Error.sourceNotFound(existingPath)) {
                    try File.System.Link.Hard.create(at: linkPath, to: existingPath)
                }
            }
        }

        @Test("Create hard link at existing path throws alreadyExists")
        func createHardLinkAtExistingPathThrows() throws {
            try File.Directory.temporary { dir in
                let existingPath = File.Path(dir.path, appending: "source.bin")
                let linkPath = File.Path(dir.path, appending: "link.bin")

                try File.System.Write.Atomic.write([1, 2, 3].span, to: existingPath)
                try File.System.Write.Atomic.write([4, 5, 6].span, to: linkPath)

                #expect(throws: File.System.Link.Hard.Error.alreadyExists(linkPath)) {
                    try File.System.Link.Hard.create(at: linkPath, to: existingPath)
                }
            }
        }

        // MARK: - Error Descriptions

        @Test("sourceNotFound error description")
        func sourceNotFoundErrorDescription() throws {
            let path = File.Path("/tmp/missing")
            let error = File.System.Link.Hard.Error.sourceNotFound(path)
            #expect(error.description.contains("Source not found"))
        }

        @Test("permissionDenied error description")
        func permissionDeniedErrorDescription() throws {
            let path = File.Path("/root/secret")
            let error = File.System.Link.Hard.Error.permissionDenied(path)
            #expect(error.description.contains("Permission denied"))
        }

        @Test("alreadyExists error description")
        func alreadyExistsErrorDescription() throws {
            let path = File.Path("/tmp/existing")
            let error = File.System.Link.Hard.Error.alreadyExists(path)
            #expect(error.description.contains("already exists"))
        }

        @Test("crossDevice error description")
        func crossDeviceErrorDescription() throws {
            let source = File.Path("/tmp/source")
            let dest = File.Path("/var/dest")
            let error = File.System.Link.Hard.Error.crossDevice(source: source, destination: dest)
            #expect(error.description.contains("Cross-device"))
        }

        @Test("isDirectory error description")
        func isDirectoryErrorDescription() throws {
            let path = File.Path("/tmp")
            let error = File.System.Link.Hard.Error.isDirectory(path)
            #expect(error.description.contains("Cannot create hard link to directory"))
        }

        @Test("linkFailed error description")
        func linkFailedErrorDescription() {
            let error = File.System.Link.Hard.Error.linkFailed(
                errno: 22,
                message: "Invalid argument"
            )
            #expect(error.description.contains("Hard link creation failed"))
        }

        // MARK: - Error Equatable

        @Test("Errors are equatable")
        func errorsAreEquatable() throws {
            let path1 = File.Path("/tmp/a")
            let path2 = File.Path("/tmp/a")

            #expect(
                File.System.Link.Hard.Error.sourceNotFound(path1)
                    == File.System.Link.Hard.Error.sourceNotFound(path2)
            )
            #expect(
                File.System.Link.Hard.Error.alreadyExists(path1)
                    == File.System.Link.Hard.Error.alreadyExists(path2)
            )
        }
    }
#endif
