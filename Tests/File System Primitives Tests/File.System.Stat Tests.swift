//
//  File.System.Stat Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Stat {
    #TestSuites
}

extension File.System.Stat.Test.Unit {

    // MARK: - Test Fixtures

    private func createTempFile(content: String = "test") throws -> String {
        let path = "/tmp/stat-test-\(Int.random(in: 0..<Int.max)).txt"
        try File.System.Write.Atomic.write(Array(content.utf8).span, to: File.Path(path))
        return path
    }

    private func createTempDirectory() throws -> String {
        let path = "/tmp/stat-test-dir-\(Int.random(in: 0..<Int.max))"
        try File.System.Create.Directory.create(at: try File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - exists()

    @Test("exists returns true for existing file")
    func existsReturnsTrueForFile() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        #expect(File.System.Stat.exists(at: filePath) == true)
    }

    @Test("exists returns true for existing directory")
    func existsReturnsTrueForDirectory() throws {
        let path = try createTempDirectory()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        #expect(File.System.Stat.exists(at: filePath) == true)
    }

    @Test("exists returns false for non-existing path")
    func existsReturnsFalseForNonExisting() throws {
        let filePath = try File.Path("/tmp/non-existing-\(Int.random(in: 0..<Int.max))")
        #expect(File.System.Stat.exists(at: filePath) == false)
    }

    // MARK: - Type checks via info()

    @Test("info returns regular type for file")
    func infoReturnsRegularForFile() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.info(at: filePath)
        #expect(info.type == .regular)
    }

    @Test("info returns directory type for directory")
    func infoReturnsDirectoryForDirectory() throws {
        let path = try createTempDirectory()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.info(at: filePath)
        #expect(info.type == .directory)
    }

    @Test("info throws for non-existing path")
    func infoThrowsForNonExisting() throws {
        let filePath = try File.Path("/tmp/non-existing-\(Int.random(in: 0..<Int.max))")
        #expect(throws: File.System.Stat.Error.self) {
            _ = try File.System.Stat.info(at: filePath)
        }
    }

    @Test("lstatInfo returns symbolicLink type for symlink")
    func lstatInfoReturnsSymlinkForSymlink() throws {
        let targetPath = try createTempFile()
        let linkPath = "/tmp/stat-test-link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path(targetPath)
        )

        let filePath = try File.Path(linkPath)
        let info = try File.System.Stat.lstatInfo(at: filePath)
        #expect(info.type == .symbolicLink)
    }

    @Test("lstatInfo returns regular type for file (not symlink)")
    func lstatInfoReturnsRegularForFile() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.lstatInfo(at: filePath)
        #expect(info.type == .regular)
    }

    @Test("lstatInfo returns directory type for directory (not symlink)")
    func lstatInfoReturnsDirectoryForDirectory() throws {
        let path = try createTempDirectory()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.lstatInfo(at: filePath)
        #expect(info.type == .directory)
    }

    // MARK: - info()

    @Test("info returns correct type for file")
    func infoReturnsCorrectTypeForFile() throws {
        let path = try createTempFile(content: "Hello, World!")
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.info(at: filePath)

        #expect(info.type == .regular)
        #expect(info.size == 13)  // "Hello, World!" is 13 bytes
    }

    @Test("info returns correct type for directory")
    func infoReturnsCorrectTypeForDirectory() throws {
        let path = try createTempDirectory()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.info(at: filePath)

        #expect(info.type == .directory)
    }

    @Test("info returns correct type for symlink")
    func infoReturnsCorrectTypeForSymlink() throws {
        let targetPath = try createTempFile()
        let linkPath = "/tmp/stat-test-link-\(Int.random(in: 0..<Int.max))"
        defer {
            cleanup(targetPath)
            cleanup(linkPath)
        }

        try File.System.Link.Symbolic.create(
            at: try File.Path(linkPath),
            pointingTo: try File.Path(targetPath)
        )

        let filePath = try File.Path(linkPath)
        let info = try File.System.Stat.info(at: filePath)

        // info() follows symlinks by default, so it should return the target type
        #expect(info.type == .regular)
    }

    // MARK: - Async variants

    @Test("async exists works")
    func asyncExists() async throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let exists = File.System.Stat.exists(at: filePath)
        #expect(exists == true)
    }

    @Test("async info returns regular type for file")
    func asyncInfo() async throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let info = try File.System.Stat.info(at: filePath)
        #expect(info.type == .regular)
    }

    // MARK: - Error cases

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() {
        let path: File.Path = "/tmp/non-existing"
        let error = File.System.Stat.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() {
        let path: File.Path = "/root/restricted"
        let error = File.System.Stat.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("statFailed error description")
    func statFailedErrorDescription() {
        let error = File.System.Stat.Error.statFailed(errno: 22, message: "Invalid argument")
        #expect(error.description.contains("Stat failed"))
        #expect(error.description.contains("Invalid argument"))
    }

    // MARK: - lstatInfo() tests

    @Test("lstatInfo returns symbolicLink type for symlink")
    func lstatInfoReturnsSymlinkType() throws {
        let targetPath = try File.Path("/tmp/stat-lstat-target-\(Int.random(in: 0..<Int.max)).txt")
        let linkPath = try File.Path("/tmp/stat-lstat-test-\(Int.random(in: 0..<Int.max))")
        defer {
            try? File.System.Delete.delete(at: targetPath)
            try? File.System.Delete.delete(at: linkPath)
        }

        // Create target file using our API
        var handle = try File.Handle.open(
            targetPath,
            mode: .write,
            options: [.create, .closeOnExec]
        )
        try handle.write(Array("test".utf8).span)
        try handle.close()

        // Create symlink using our API
        try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

        // lstatInfo should return symbolicLink type (doesn't follow)
        let lstatInfo = try File.System.Stat.lstatInfo(at: linkPath)
        #expect(lstatInfo.type == .symbolicLink)

        // info should return regular type (follows symlink)
        let statInfo = try File.System.Stat.info(at: linkPath)
        #expect(statInfo.type == .regular)
    }

    @Test("lstatInfo returns different inode than info for symlink")
    func lstatInfoReturnsDifferentInodeForSymlink() throws {
        let targetPath = try File.Path("/tmp/stat-inode-target-\(Int.random(in: 0..<Int.max)).txt")
        let linkPath = try File.Path("/tmp/stat-inode-test-\(Int.random(in: 0..<Int.max))")
        defer {
            try? File.System.Delete.delete(at: targetPath)
            try? File.System.Delete.delete(at: linkPath)
        }

        // Create target file using our API
        var handle = try File.Handle.open(
            targetPath,
            mode: .write,
            options: [.create, .closeOnExec]
        )
        try handle.write(Array("test".utf8).span)
        try handle.close()

        // Create symlink using our API
        try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

        // lstatInfo returns the symlink's own inode
        let lstatInfo = try File.System.Stat.lstatInfo(at: linkPath)

        // info on symlink follows to target, should have same inode as target
        let statInfo = try File.System.Stat.info(at: linkPath)
        let targetInfo = try File.System.Stat.info(at: targetPath)

        // The symlink has its own inode, different from the target
        #expect(lstatInfo.inode != targetInfo.inode)

        // info() on symlink should return the target's inode
        #expect(statInfo.inode == targetInfo.inode)
    }

    @Test("lstatInfo same as info for regular file")
    func lstatInfoSameAsInfoForRegularFile() throws {
        let filePath = try File.Path("/tmp/stat-lstat-regular-\(Int.random(in: 0..<Int.max)).txt")
        defer { try? File.System.Delete.delete(at: filePath) }

        // Create file using our API
        var handle = try File.Handle.open(
            filePath,
            mode: .write,
            options: [.create, .closeOnExec]
        )
        try handle.write(Array("test content".utf8).span)
        try handle.close()

        let lstatInfo = try File.System.Stat.lstatInfo(at: filePath)
        let statInfo = try File.System.Stat.info(at: filePath)

        // For regular files, both should return the same info
        #expect(lstatInfo.type == statInfo.type)
        #expect(lstatInfo.inode == statInfo.inode)
        #expect(lstatInfo.size == statInfo.size)
    }
}

// MARK: - Performance Tests

extension File.System.Stat.Test.Performance {

    @Test("File.System.Stat.info", .timed(iterations: 100, warmup: 10))
    func statInfo() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(td, appending: "perf_stat_\(Int.random(in: 0..<Int.max)).txt")

        // Create file
        let data = [UInt8](repeating: 0x00, count: 1000)
        try File.System.Write.Atomic.write(data.span, to: filePath)

        defer { try? File.System.Delete.delete(at: filePath) }

        let _ = try File.System.Stat.info(at: filePath)
    }

    @Test("File.System.Stat.exists check", .timed(iterations: 100, warmup: 10))
    func existsCheck() throws {
        let td = try File.Directory.Temporary.system
        let filePath = File.Path(
            td,
            appending: "perf_exists_\(Int.random(in: 0..<Int.max)).txt"
        )

        // Create file
        let data = [UInt8](repeating: 0x00, count: 100)
        try File.System.Write.Atomic.write(data.span, to: filePath)

        defer { try? File.System.Delete.delete(at: filePath) }

        let exists = File.System.Stat.exists(at: filePath)
        #expect(exists)
    }
}
