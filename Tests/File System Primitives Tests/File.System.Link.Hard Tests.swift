//
//  File.System.Link.Hard Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing
import StandardsTestSupport
@testable import File_System_Primitives

extension File.System.Link.Hard {
    #TestSuites
}

extension File.System.Link.Hard.Test.Unit {

    // MARK: - Test Fixtures

    private func writeBytes(_ bytes: [UInt8], to path: File.Path) throws {
        var bytes = bytes
        try bytes.withUnsafeMutableBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
    }

    /// Writes bytes in-place using a file handle (doesn't replace the file).
    /// This is important for hard link tests where we need to preserve the inode.
    private func writeBytesInPlace(_ bytes: [UInt8], to path: File.Path) throws {
        var handle = try File.Handle.open(path, mode: .write, options: [.truncate])
        try bytes.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try handle.write(span)
        }
        try handle.close()
    }

    private func createTempFile(content: [UInt8] = [1, 2, 3]) throws -> String {
        let path = "/tmp/hardlink-test-\(Int.random(in: 0..<Int.max)).bin"
        try writeBytes(content, to: try File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        try? File.System.Delete.delete(at: try! File.Path(path), options: .init(recursive: true))
    }

    // MARK: - Create Hard Link

    @Test("Create hard link to file")
    func createHardLinkToFile() throws {
        let existingPath = try createTempFile(content: [1, 2, 3])
        let linkPath = "/tmp/hardlink-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(existingPath)
            cleanup(linkPath)
        }

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Hard.create(at: link, to: existing)

        #expect(File.System.Stat.exists(at: try File.Path(linkPath)))

        // Both files should have same content
        let existingData = try File.System.Read.Full.read(from: try File.Path(existingPath))
        let linkData = try File.System.Read.Full.read(from: try File.Path(linkPath))
        #expect(existingData == linkData)
    }

    @Test("Hard link shares inode with original")
    func hardLinkSharesInode() throws {
        let existingPath = try createTempFile(content: [1, 2, 3])
        let linkPath = "/tmp/hardlink-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(existingPath)
            cleanup(linkPath)
        }

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Hard.create(at: link, to: existing)

        // Get inode numbers using our stat API
        let existingInfo = try File.System.Stat.info(at: try File.Path(existingPath))
        let linkInfo = try File.System.Stat.info(at: try File.Path(linkPath))

        #expect(existingInfo.inode == linkInfo.inode)
    }

    @Test("Modifying hard link modifies original")
    func modifyingHardLinkModifiesOriginal() throws {
        let existingPath = try createTempFile(content: [1, 2, 3])
        let linkPath = "/tmp/hardlink-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(existingPath)
            cleanup(linkPath)
        }

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Hard.create(at: link, to: existing)

        // Modify through the link using in-place write (not atomic write which replaces the file)
        try writeBytesInPlace([10, 20, 30], to: try File.Path(linkPath))

        // Original should also be modified (same inode)
        let originalData = try File.System.Read.Full.read(from: try File.Path(existingPath))
        #expect(originalData == [10, 20, 30])
    }

    @Test("Deleting original does not delete hard link")
    func deletingOriginalDoesNotDeleteHardLink() throws {
        let existingPath = try createTempFile(content: [1, 2, 3])
        let linkPath = "/tmp/hardlink-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(linkPath)
        }

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Hard.create(at: link, to: existing)

        // Delete original
        try File.System.Delete.delete(at: try File.Path(existingPath))

        // Hard link should still exist and have the data
        #expect(File.System.Stat.exists(at: try File.Path(linkPath)))
        let data = try File.System.Read.Full.read(from: try File.Path(linkPath))
        #expect(data == [1, 2, 3])
    }

    // MARK: - Error Cases

    @Test("Create hard link to non-existent file throws sourceNotFound")
    func createHardLinkToNonExistentThrows() throws {
        let existingPath = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let linkPath = "/tmp/hardlink-\(Int.random(in: 0..<Int.max))"

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        #expect(throws: File.System.Link.Hard.Error.sourceNotFound(existing)) {
            try File.System.Link.Hard.create(at: link, to: existing)
        }
    }

    @Test("Create hard link at existing path throws alreadyExists")
    func createHardLinkAtExistingPathThrows() throws {
        let existingPath = try createTempFile()
        let linkPath = try createTempFile()
        defer {
            cleanup(existingPath)
            cleanup(linkPath)
        }

        let existing = try File.Path(existingPath)
        let link = try File.Path(linkPath)

        #expect(throws: File.System.Link.Hard.Error.alreadyExists(link)) {
            try File.System.Link.Hard.create(at: link, to: existing)
        }
    }

    // MARK: - Error Descriptions

    @Test("sourceNotFound error description")
    func sourceNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.System.Link.Hard.Error.sourceNotFound(path)
        #expect(error.description.contains("Source not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root/secret")
        let error = File.System.Link.Hard.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("alreadyExists error description")
    func alreadyExistsErrorDescription() throws {
        let path = try File.Path("/tmp/existing")
        let error = File.System.Link.Hard.Error.alreadyExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("crossDevice error description")
    func crossDeviceErrorDescription() throws {
        let source = try File.Path("/tmp/source")
        let dest = try File.Path("/var/dest")
        let error = File.System.Link.Hard.Error.crossDevice(source: source, destination: dest)
        #expect(error.description.contains("Cross-device"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() throws {
        let path = try File.Path("/tmp")
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
        let path1 = try File.Path("/tmp/a")
        let path2 = try File.Path("/tmp/a")

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
