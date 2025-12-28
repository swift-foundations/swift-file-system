//
//  File.System.Delete Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Delete {
    #TestSuites
}

extension File.System.Delete.Test.Unit {

    // MARK: - Delete file

    @Test("Delete existing file")
    func deleteExistingFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")
            try File.System.Write.Atomic.write(Array("test".utf8).span, to: filePath)

            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: filePath))
        }
    }

    @Test("Delete non-existing file throws pathNotFound")
    func deleteNonExistingFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "non-existing.txt")

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: filePath)
            }
        }
    }

    // MARK: - Delete directory

    @Test("Delete empty directory")
    func deleteEmptyDirectory() throws {
        try File.Directory.temporary { dir in
            let subdir = File.Path(dir.path, appending: "subdir")
            try File.System.Create.Directory.create(at: subdir)

            try File.System.Delete.delete(at: subdir)

            #expect(!File.System.Stat.exists(at: subdir))
        }
    }

    @Test("Delete non-empty directory without recursive throws")
    func deleteNonEmptyDirectoryWithoutRecursive() throws {
        try File.Directory.temporary { dir in
            let subdir = File.Path(dir.path, appending: "subdir")
            try File.System.Create.Directory.create(at: subdir)
            try File.System.Write.Atomic.write(Array("content".utf8), to: File.Path(subdir, appending: "file.txt"))

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: subdir)
            }

            // Directory should still exist
            #expect(File.System.Stat.exists(at: subdir))
        }
    }

    @Test("Delete non-empty directory with recursive option")
    func deleteNonEmptyDirectoryWithRecursive() throws {
        try File.Directory.temporary { dir in
            // Create nested structure
            let nested = File.Path(dir.path, appending: "a/b/c")
            try File.System.Create.Directory.create(at: nested, options: .init(createIntermediates: true))
            try File.System.Write.Atomic.write(Array("file1".utf8), to: File.Path(dir.path, appending: "a/file1.txt"))
            try File.System.Write.Atomic.write(Array("file2".utf8), to: File.Path(dir.path, appending: "a/b/file2.txt"))

            let targetDir = File.Path(dir.path, appending: "a")
            try File.System.Delete.delete(at: targetDir, options: .init(recursive: true))

            #expect(!File.System.Stat.exists(at: targetDir))
        }
    }

    // MARK: - Options

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.System.Delete.Options()
        #expect(options.recursive == false)
    }

    @Test("Options recursive true")
    func optionsRecursiveTrue() {
        let options = File.System.Delete.Options(recursive: true)
        #expect(options.recursive == true)
    }

    // MARK: - Additional variants

    @Test("Delete file variant")
    func deleteFileVariant() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "variant.txt")
            try File.System.Write.Atomic.write(Array("test".utf8).span, to: filePath)

            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: filePath))
        }
    }

    @Test("Delete directory with options variant")
    func deleteDirectoryWithOptionsVariant() throws {
        try File.Directory.temporary { dir in
            let nested = File.Path(dir.path, appending: "nested/deep")
            try File.System.Create.Directory.create(at: nested, options: .init(createIntermediates: true))
            try File.System.Write.Atomic.write(Array("content".utf8), to: File.Path(dir.path, appending: "nested/file.txt"))

            let targetDir = File.Path(dir.path, appending: "nested")
            try File.System.Delete.delete(at: targetDir, options: .init(recursive: true))

            #expect(!File.System.Stat.exists(at: targetDir))
        }
    }

    // MARK: - Error descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path: File.Path = "/tmp/missing.txt"
        let error = File.System.Delete.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
        #expect(error.description.contains(String(path)))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path: File.Path = "/root/protected"
        let error = File.System.Delete.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() throws {
        let path: File.Path = "/tmp/somedir"
        let error = File.System.Delete.Error.isDirectory(path)
        #expect(error.description.contains("Is a directory"))
        #expect(error.description.contains("recursive"))
    }

    @Test("directoryNotEmpty error description")
    func directoryNotEmptyErrorDescription() throws {
        let path: File.Path = "/tmp/nonempty"
        let error = File.System.Delete.Error.directoryNotEmpty(path)
        #expect(error.description.contains("Directory not empty"))
        #expect(error.description.contains("recursive"))
    }

    @Test("deleteFailed error description")
    func deleteFailedErrorDescription() {
        let error = File.System.Delete.Error.deleteFailed(
            errno: 16,
            message: "Device or resource busy"
        )
        #expect(error.description.contains("Delete failed"))
        #expect(error.description.contains("Device or resource busy"))
        #expect(error.description.contains("16"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1: File.Path = "/tmp/a"
        let path2: File.Path = "/tmp/a"
        let path3: File.Path = "/tmp/b"

        #expect(
            File.System.Delete.Error.pathNotFound(path1)
                == File.System.Delete.Error.pathNotFound(path2)
        )
        #expect(
            File.System.Delete.Error.pathNotFound(path1)
                != File.System.Delete.Error.pathNotFound(path3)
        )
        #expect(
            File.System.Delete.Error.pathNotFound(path1)
                != File.System.Delete.Error.permissionDenied(path1)
        )
    }
}
