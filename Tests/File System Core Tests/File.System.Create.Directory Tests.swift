//
//  File.System.Create.Directory Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Create.Directory {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Create.Directory.Test.Unit {
    // MARK: - create() basic

    @Test
    func `Create directory at path`() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.path / "test-dir"
            try File.System.Create.Directory.create(at: testDir)

            #expect(File.System.Stat.exists(at: testDir))
            let stat = try File.System.Stat.info(at: testDir)
            #expect(stat.type == .directory)
        }
    }

    @Test
    func `Create directory throws if already exists`() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.path / "test-dir"
            try File.System.Create.Directory.create(at: testDir)

            #expect(throws: File.System.Create.Directory.Error.self) {
                try File.System.Create.Directory.create(at: testDir)
            }
        }
    }

    @Test
    func `Create directory throws if parent doesn't exist`() throws {
        try File.Directory.temporary { dir in
            let nonExistentPath = dir.path / "nonexistent" / "child"

            #expect(throws: File.System.Create.Directory.Error.self) {
                try File.System.Create.Directory.create(at: nonExistentPath)
            }
        }
    }

    // MARK: - create() with options

    @Test
    func `Create directory with createIntermediates`() throws {
        try File.Directory.temporary { dir in
            let nestedPath = dir.path / "a" / "b" / "c"
            try File.System.Create.Directory.create(at: nestedPath, createIntermediates: true)

            #expect(File.System.Stat.exists(at: nestedPath))
            #expect(File.System.Stat.exists(at: dir.path / "a"))
            #expect(File.System.Stat.exists(at: dir.path / "a" / "b"))
        }
    }

    @Test
    func `Create directory without createIntermediates fails for nested path`() throws {
        try File.Directory.temporary { dir in
            let nestedPath = dir.path / "a" / "b" / "c"

            #expect(throws: File.System.Create.Directory.Error.self) {
                try File.System.Create.Directory.create(at: nestedPath)
            }
        }
    }

    @Test
    func `Create directory with custom permissions`() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.path / "test-dir"
            let permissions: File.System.Metadata.Permissions = [
                .ownerRead, .ownerWrite, .ownerExecute,
            ]
            let options = File.System.Create.Directory.Options(permissions: permissions)
            try File.System.Create.Directory.create(at: testDir, options: options)

            #expect(File.System.Stat.exists(at: testDir))
            // Directory should exist (permission verification is platform-specific)
        }
    }

    // MARK: - Options

    @Test
    func `Options default values`() {
        let options = File.System.Create.Directory.Options()
        #expect(options.permissions == nil)
    }

    @Test
    func `Options custom values`() {
        let permissions: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]
        let options = File.System.Create.Directory.Options(
            permissions: permissions
        )
        #expect(options.permissions == permissions)
    }

    // MARK: - Additional variants

    @Test
    func `Create directory variant`() throws {
        try File.Directory.temporary { dir in
            let testDir = dir.path / "test-dir"
            try File.System.Create.Directory.create(at: testDir)

            #expect(File.System.Stat.exists(at: testDir))
        }
    }

    @Test
    func `Create directory with options variant`() throws {
        try File.Directory.temporary { dir in
            let nestedPath = dir.path / "nested" / "dir"
            try File.System.Create.Directory.create(at: nestedPath, createIntermediates: true)

            #expect(File.System.Stat.exists(at: nestedPath))
        }
    }

    // MARK: - Semantic Accessors

    @Test
    func `isAlreadyExists semantic accessor`() {
        let error = File.System.Create.Directory.Error.mkdir(.exists)
        #expect(error.isAlreadyExists)
        #expect(!error.isPermissionDenied)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Create.Directory.Error.mkdir(.permission)
        #expect(error.isPermissionDenied)
        #expect(!error.isAlreadyExists)
    }

    @Test
    func `isParentNotFound semantic accessor`() {
        let error = File.System.Create.Directory.Error.mkdir(.notFound)
        #expect(error.isParentNotFound)
        #expect(!error.isAlreadyExists)
    }

    @Test
    func `isReadOnly semantic accessor`() {
        let error = File.System.Create.Directory.Error.mkdir(.readOnly)
        #expect(error.isReadOnly)
        #expect(!error.isAlreadyExists)
    }

    @Test
    func `isNoSpace semantic accessor`() {
        let error = File.System.Create.Directory.Error.mkdir(.noSpace)
        #expect(error.isNoSpace)
        #expect(!error.isAlreadyExists)
    }

    @Test
    // swiftlint:disable:next swift_error_qualification - backtick test description, not a type reference
    func `Error description contains failure message`() {
        let error = File.System.Create.Directory.Error.mkdir(.exists)
        #expect(error.description.contains("Directory creation failed"))
    }

    // MARK: - Error Equatable

    @Test
    func `Errors are equatable`() {
        #expect(
            File.System.Create.Directory.Error.mkdir(.exists)
                == File.System.Create.Directory.Error.mkdir(.exists)
        )
        #expect(
            File.System.Create.Directory.Error.mkdir(.exists)
                != File.System.Create.Directory.Error.mkdir(.permission)
        )
    }
}
