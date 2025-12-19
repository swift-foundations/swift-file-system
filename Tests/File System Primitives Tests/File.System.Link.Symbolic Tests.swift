//
//  File.System.Link.Symbolic Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Link.Symbolic {
    #TestSuites
}

extension File.System.Link.Symbolic.Test.Unit {

    // MARK: - Test Fixtures

    private func writeBytes(_ bytes: [UInt8], to path: File.Path) throws {
        var bytes = bytes
        try bytes.withUnsafeMutableBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: path)
        }
    }

    private func createTempFile(content: [UInt8] = [1, 2, 3]) throws -> String {
        let path = "/tmp/symlink-test-\(Int.random(in: 0..<Int.max)).bin"
        try writeBytes(content, to: try File.Path(path))
        return path
    }

    private func createTempDir() throws -> String {
        let path = "/tmp/symlink-dir-\(Int.random(in: 0..<Int.max))"
        try File.System.Create.Directory.create(at: try File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - Create Symlink

    @Test("Create symlink to file")
    func createSymlinkToFile() throws {
        let targetPath = try createTempFile(content: [1, 2, 3])
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        let target = try File.Path(targetPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Symbolic.create(at: link, pointingTo: target)

        // Verify symlink exists
        #expect(File.System.Stat.exists(at: try File.Path(linkPath)))

        // Verify it's a symlink using lstatInfo
        let info = try File.System.Stat.lstatInfo(at: try File.Path(linkPath))
        #expect(info.type == .symbolicLink)
    }

    @Test("Create symlink to directory")
    func createSymlinkToDirectory() throws {
        let targetPath = try createTempDir()
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        let target = try File.Path(targetPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Symbolic.create(at: link, pointingTo: target)

        let info = try File.System.Stat.lstatInfo(at: try File.Path(linkPath))
        #expect(info.type == .symbolicLink)
    }

    @Test("Symlink points to correct target")
    func symlinkPointsToCorrectTarget() throws {
        let targetPath = try createTempFile(content: [10, 20, 30])
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        let target = try File.Path(targetPath)
        let link = try File.Path(linkPath)

        try File.System.Link.Symbolic.create(at: link, pointingTo: target)

        // Read through symlink
        let data = try File.System.Read.Full.read(from: try File.Path(linkPath))
        #expect(data == [10, 20, 30])
    }

    @Test("Create symlink to non-existent target succeeds")
    func createSymlinkToNonExistentTarget() throws {
        let targetPath = "/tmp/non-existent-target-\(Int.random(in: 0..<Int.max))"
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(linkPath)
        }

        let target = try File.Path(targetPath)
        let link = try File.Path(linkPath)

        // Creating symlink to non-existent target should succeed
        // (it's a dangling symlink, but that's allowed)
        try File.System.Link.Symbolic.create(at: link, pointingTo: target)

        let info = try File.System.Stat.lstatInfo(at: try File.Path(linkPath))
        #expect(info.type == .symbolicLink)
    }

    // MARK: - Error Cases

    @Test("Create symlink at existing path throws alreadyExists")
    func createSymlinkAtExistingPathThrows() throws {
        let targetPath = try createTempFile()
        let linkPath = try createTempFile()
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        let target = try File.Path(targetPath)
        let link = try File.Path(linkPath)

        #expect(throws: File.System.Link.Symbolic.Error.alreadyExists(link)) {
            try File.System.Link.Symbolic.create(at: link, pointingTo: target)
        }
    }

    // MARK: - Error Descriptions

    @Test("targetNotFound error description")
    func targetNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.System.Link.Symbolic.Error.targetNotFound(path)
        #expect(error.description.contains("Target not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root/secret")
        let error = File.System.Link.Symbolic.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("alreadyExists error description")
    func alreadyExistsErrorDescription() throws {
        let path = try File.Path("/tmp/existing")
        let error = File.System.Link.Symbolic.Error.alreadyExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("linkFailed error description")
    func linkFailedErrorDescription() {
        let error = File.System.Link.Symbolic.Error.linkFailed(
            errno: 22,
            message: "Invalid argument"
        )
        #expect(error.description.contains("Symlink creation failed"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = try File.Path("/tmp/a")
        let path2 = try File.Path("/tmp/a")

        #expect(
            File.System.Link.Symbolic.Error.alreadyExists(path1)
                == File.System.Link.Symbolic.Error.alreadyExists(path2)
        )
        #expect(
            File.System.Link.Symbolic.Error.targetNotFound(path1)
                == File.System.Link.Symbolic.Error.targetNotFound(path2)
        )
    }
}
