//
//  File.System.Link.Read.Target Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Link.Read.Target {
    #TestSuites
}

extension File.System.Link.Read.Target.Test.Unit {
    // MARK: - Test Fixtures

    private func createTempFile(content: [UInt8] = [1, 2, 3]) throws -> String {
        let path = "/tmp/readtarget-test-\(Int.random(in: 0..<Int.max)).bin"
        try File.System.Write.Atomic.write(content.span, to: File.Path(path))
        return path
    }

    private func createTempDir() throws -> String {
        let path = "/tmp/readtarget-dir-\(Int.random(in: 0..<Int.max))"
        try File.System.Create.Directory.create(at: try File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - Read Target

    @Test("Read target of symlink to file")
    func readTargetOfSymlinkToFile() throws {
        let targetPath = try createTempFile()
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path(targetPath)
        )

        let link = try File.Path(linkPath)
        let target = try File.System.Link.Read.Target.target(of: link)

        #expect(target.string == targetPath)
    }

    @Test("Read target of symlink to directory")
    func readTargetOfSymlinkToDirectory() throws {
        let targetPath = try createTempDir()
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path(targetPath)
        )

        let link = try File.Path(linkPath)
        let target = try File.System.Link.Read.Target.target(of: link)

        #expect(target.string == targetPath)
    }

    @Test("Read target of dangling symlink")
    func readTargetOfDanglingSymlink() throws {
        let targetPath = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let linkPath = "/tmp/link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(linkPath)
        }

        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path(targetPath)
        )

        let link = try File.Path(linkPath)
        let target = try File.System.Link.Read.Target.target(of: link)

        #expect(target.string == targetPath)
    }

    @Test("Read target of relative symlink")
    func readTargetOfRelativeSymlink() throws {
        let dirPath = try createTempDir()
        let targetPath = "\(dirPath)/target.txt"
        let linkPath = "\(dirPath)/link.txt"
        defer {
            cleanup(dirPath)
        }

        // Create target file
        try File.System.Write.Atomic.write([], to: File.Path(targetPath))

        // Create relative symlink
        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path("target.txt")
        )

        let link = try File.Path(linkPath)
        let target = try File.System.Link.Read.Target.target(of: link)

        #expect(target.string == "target.txt")
    }

    // MARK: - Error Cases

    @Test("Read target of regular file throws notASymlink")
    func readTargetOfRegularFileThrows() throws {
        let filePath = try createTempFile()
        defer { cleanup(filePath) }

        let path = try File.Path(filePath)

        #expect(throws: File.System.Link.Read.Target.Error.notASymlink(path)) {
            _ = try File.System.Link.Read.Target.target(of: path)
        }
    }

    @Test("Read target of directory throws notASymlink")
    func readTargetOfDirectoryThrows() throws {
        let dirPath = try createTempDir()
        defer { cleanup(dirPath) }

        let path = try File.Path(dirPath)

        #expect(throws: File.System.Link.Read.Target.Error.notASymlink(path)) {
            _ = try File.System.Link.Read.Target.target(of: path)
        }
    }

    @Test("Read target of non-existent path throws pathNotFound")
    func readTargetOfNonExistentPathThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)

        #expect(throws: File.System.Link.Read.Target.Error.pathNotFound(path)) {
            _ = try File.System.Link.Read.Target.target(of: path)
        }
    }

    // MARK: - Error Descriptions

    @Test("notASymlink error description")
    func notASymlinkErrorDescription() throws {
        let path = try File.Path("/tmp/regular")
        let error = File.System.Link.Read.Target.Error.notASymlink(path)
        #expect(error.description.contains("Not a symbolic link"))
    }

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.System.Link.Read.Target.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root/secret")
        let error = File.System.Link.Read.Target.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("readFailed error description")
    func readFailedErrorDescription() {
        let error = File.System.Link.Read.Target.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read link target failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = try File.Path("/tmp/a")
        let path2 = try File.Path("/tmp/a")

        #expect(
            File.System.Link.Read.Target.Error.notASymlink(path1)
                == File.System.Link.Read.Target.Error.notASymlink(path2)
        )
        #expect(
            File.System.Link.Read.Target.Error.pathNotFound(path1)
                == File.System.Link.Read.Target.Error.pathNotFound(path2)
        )
    }

}
