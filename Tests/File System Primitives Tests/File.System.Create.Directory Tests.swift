//
//  File.System.Create.Directory Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Create.Directory {
    #TestSuites
}

extension File.System.Create.Directory.Test.Unit {
    // MARK: - Test Fixtures

    private func uniquePath() -> String {
        "/tmp/create-dir-test-\(Int.random(in: 0..<Int.max))"
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - create() basic

    @Test("Create directory at path")
    func createDirectory() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        try File.System.Create.Directory.create(at: filePath)

        #expect(File.System.Stat.exists(at: try File.Path(path)))
        let stat = try File.System.Stat.info(at: try File.Path(path))
        #expect(stat.type == .directory)
    }

    @Test("Create directory throws if already exists")
    func createDirectoryAlreadyExists() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        try File.System.Create.Directory.create(at: try File.Path(path))

        let filePath = try File.Path(path)
        #expect(throws: File.System.Create.Directory.Error.self) {
            try File.System.Create.Directory.create(at: filePath)
        }
    }

    @Test("Create directory throws if parent doesn't exist")
    func createDirectoryParentNotFound() throws {
        let nonExistentParent = uniquePath()
        let path = "\(nonExistentParent)/child"

        let filePath = try File.Path(path)
        #expect(throws: File.System.Create.Directory.Error.self) {
            try File.System.Create.Directory.create(at: filePath)
        }
    }

    // MARK: - create() with options

    @Test("Create directory with createIntermediates")
    func createDirectoryWithIntermediates() throws {
        let basePath = uniquePath()
        let path = "\(basePath)/a/b/c"
        defer { cleanup(basePath) }

        let filePath = try File.Path(path)
        let options = File.System.Create.Directory.Options(createIntermediates: true)
        try File.System.Create.Directory.create(at: filePath, options: options)

        #expect(File.System.Stat.exists(at: try File.Path(path)))
        #expect(File.System.Stat.exists(at: try File.Path("\(basePath)/a")))
        #expect(File.System.Stat.exists(at: try File.Path("\(basePath)/a/b")))
    }

    @Test("Create directory without createIntermediates fails for nested path")
    func createDirectoryWithoutIntermediatesFails() throws {
        let basePath = uniquePath()
        let path = "\(basePath)/a/b/c"

        let filePath = try File.Path(path)
        let options = File.System.Create.Directory.Options(createIntermediates: false)

        #expect(throws: File.System.Create.Directory.Error.self) {
            try File.System.Create.Directory.create(at: filePath, options: options)
        }
    }

    @Test("Create directory with custom permissions")
    func createDirectoryWithPermissions() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let permissions: File.System.Metadata.Permissions = [
            .ownerRead, .ownerWrite, .ownerExecute,
        ]
        let options = File.System.Create.Directory.Options(permissions: permissions)
        try File.System.Create.Directory.create(at: filePath, options: options)

        #expect(File.System.Stat.exists(at: try File.Path(path)))
        // Directory should exist (permission verification is platform-specific)
    }

    // MARK: - Options

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.System.Create.Directory.Options()
        #expect(options.createIntermediates == false)
        #expect(options.permissions == nil)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
        let permissions: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]
        let options = File.System.Create.Directory.Options(
            createIntermediates: true,
            permissions: permissions
        )
        #expect(options.createIntermediates == true)
        #expect(options.permissions == permissions)
    }

    // MARK: - Async variants

    @Test("Async create directory")
    func asyncCreateDirectory() async throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        try await File.System.Create.Directory.create(at: filePath)

        #expect(File.System.Stat.exists(at: try File.Path(path)))
    }

    @Test("Async create directory with options")
    func asyncCreateDirectoryWithOptions() async throws {
        let basePath = uniquePath()
        let path = "\(basePath)/nested/dir"
        defer { cleanup(basePath) }

        let filePath = try File.Path(path)
        let options = File.System.Create.Directory.Options(createIntermediates: true)
        try await File.System.Create.Directory.create(at: filePath, options: options)

        #expect(File.System.Stat.exists(at: try File.Path(path)))
    }

    // MARK: - Error descriptions

    @Test("alreadyExists error description")
    func alreadyExistsErrorDescription() throws {
        let path: File.Path = try .init("/tmp/existing")
        let error = File.System.Create.Directory.Error.alreadyExists(path)
        #expect(error.description.contains("Directory already exists"))
        #expect(error.description.contains("/tmp/existing"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path: File.Path = try .init("/root/forbidden")
        let error = File.System.Create.Directory.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("parentDirectoryNotFound error description")
    func parentDirectoryNotFoundErrorDescription() throws {
        let path: File.Path = try .init("/nonexistent/dir")
        let error = File.System.Create.Directory.Error.parentDirectoryNotFound(path)
        #expect(error.description.contains("Parent directory not found"))
    }

    @Test("createFailed error description")
    func createFailedErrorDescription() {
        let error = File.System.Create.Directory.Error.createFailed(
            errno: 22,
            message: "Invalid argument"
        )
        #expect(error.description.contains("Create failed"))
        #expect(error.description.contains("Invalid argument"))
        #expect(error.description.contains("22"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1: File.Path = try .init("/tmp/a")
        let path2: File.Path = try .init("/tmp/a")
        let path3: File.Path = try .init("/tmp/b")

        #expect(
            File.System.Create.Directory.Error.alreadyExists(path1)
                == File.System.Create.Directory.Error.alreadyExists(path2)
        )
        #expect(
            File.System.Create.Directory.Error.alreadyExists(path1)
                != File.System.Create.Directory.Error.alreadyExists(path3)
        )
        #expect(
            File.System.Create.Directory.Error.alreadyExists(path1)
                != File.System.Create.Directory.Error.permissionDenied(path1)
        )
    }
}

// MARK: - Performance Tests

extension File.System.Create.Directory.Test.Performance {

    @Test("Create and delete directory", .timed(iterations: 50, warmup: 5))
    func createDeleteDirectory() throws {
        let td = try tempDir()
        let testDir = File.Path(td, appending: "perf_mkdir_\(Int.random(in: 0..<Int.max))")

        try File.System.Create.Directory.create(at: testDir)
        try File.System.Delete.delete(at: testDir)
    }
}
