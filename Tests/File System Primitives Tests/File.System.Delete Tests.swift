//
//  File.System.Delete Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing

@testable import File_System_Primitives

extension File.System.Test.Unit {
    @Suite("File.System.Delete")
    struct Delete {

        // MARK: - Test Fixtures

        private func writeBytes(_ bytes: [UInt8], to path: File.Path) throws {
            var bytes = bytes
            try bytes.withUnsafeMutableBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: path)
            }
        }

        private func createTempFile(content: String = "test") throws -> String {
            let path = "/tmp/delete-test-\(Int.random(in: 0..<Int.max)).txt"
            try writeBytes(Array(content.utf8), to: try File.Path(path))
            return path
        }

        private func createTempDirectory() throws -> String {
            let path = "/tmp/delete-test-dir-\(Int.random(in: 0..<Int.max))"
            try File.System.Create.Directory.create(at: try File.Path(path))
            return path
        }

        private func createNestedDirectory() throws -> String {
            let basePath = "/tmp/delete-test-nested-\(Int.random(in: 0..<Int.max))"
            let nestedPath = "\(basePath)/a/b/c"
            try File.System.Create.Directory.create(
                at: try File.Path(nestedPath),
                options: .init(createIntermediates: true)
            )
            // Add some files
            try writeBytes(Array("file1".utf8), to: try File.Path("\(basePath)/file1.txt"))
            try writeBytes(Array("file2".utf8), to: try File.Path("\(basePath)/a/file2.txt"))
            try writeBytes(Array("file3".utf8), to: try File.Path("\(basePath)/a/b/file3.txt"))
            return basePath
        }

        private func cleanup(_ path: String) {
            try? File.System.Delete.delete(at: try! File.Path(path), options: .init(recursive: true))
        }

        // MARK: - Delete file

        @Test("Delete existing file")
        func deleteExistingFile() throws {
            let path = try createTempFile()

            let filePath = try File.Path(path)
            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: try File.Path(path)))
        }

        @Test("Delete non-existing file throws pathNotFound")
        func deleteNonExistingFile() throws {
            let path = "/tmp/non-existing-\(Int.random(in: 0..<Int.max)).txt"
            let filePath = try File.Path(path)

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: filePath)
            }
        }

        // MARK: - Delete directory

        @Test("Delete empty directory")
        func deleteEmptyDirectory() throws {
            let path = try createTempDirectory()

            let filePath = try File.Path(path)
            try File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: try File.Path(path)))
        }

        @Test("Delete non-empty directory without recursive throws")
        func deleteNonEmptyDirectoryWithoutRecursive() throws {
            let basePath = try createNestedDirectory()
            defer { cleanup(basePath) }

            let filePath = try File.Path(basePath)

            #expect(throws: File.System.Delete.Error.self) {
                try File.System.Delete.delete(at: filePath)
            }

            // Directory should still exist
            #expect(File.System.Stat.exists(at: try File.Path(basePath)))
        }

        @Test("Delete non-empty directory with recursive option")
        func deleteNonEmptyDirectoryWithRecursive() throws {
            let basePath = try createNestedDirectory()

            let filePath = try File.Path(basePath)
            let options = File.System.Delete.Options(recursive: true)
            try File.System.Delete.delete(at: filePath, options: options)

            #expect(!File.System.Stat.exists(at: try File.Path(basePath)))
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

        // MARK: - Async variants

        @Test("Async delete file")
        func asyncDeleteFile() async throws {
            let path = try createTempFile()

            let filePath = try File.Path(path)
            try await File.System.Delete.delete(at: filePath)

            #expect(!File.System.Stat.exists(at: try File.Path(path)))
        }

        @Test("Async delete directory with options")
        func asyncDeleteDirectoryWithOptions() async throws {
            let basePath = try createNestedDirectory()

            let filePath = try File.Path(basePath)
            let options = File.System.Delete.Options(recursive: true)
            try await File.System.Delete.delete(at: filePath, options: options)

            #expect(!File.System.Stat.exists(at: try File.Path(basePath)))
        }

        // MARK: - Error descriptions

        @Test("pathNotFound error description")
        func pathNotFoundErrorDescription() throws {
            let path = try File.Path("/tmp/missing.txt")
            let error = File.System.Delete.Error.pathNotFound(path)
            #expect(error.description.contains("Path not found"))
            #expect(error.description.contains("/tmp/missing.txt"))
        }

        @Test("permissionDenied error description")
        func permissionDeniedErrorDescription() throws {
            let path = try File.Path("/root/protected")
            let error = File.System.Delete.Error.permissionDenied(path)
            #expect(error.description.contains("Permission denied"))
        }

        @Test("isDirectory error description")
        func isDirectoryErrorDescription() throws {
            let path = try File.Path("/tmp/somedir")
            let error = File.System.Delete.Error.isDirectory(path)
            #expect(error.description.contains("Is a directory"))
            #expect(error.description.contains("recursive"))
        }

        @Test("directoryNotEmpty error description")
        func directoryNotEmptyErrorDescription() throws {
            let path = try File.Path("/tmp/nonempty")
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
            let path1 = try File.Path("/tmp/a")
            let path2 = try File.Path("/tmp/a")
            let path3 = try File.Path("/tmp/b")

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
}
