//
//  File.System.Write.Atomic Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic {
    #TestSuites
}

extension File.System.Write.Atomic.Test.Unit {

    // MARK: - Test Fixtures

    private func uniquePath(extension ext: String = "txt") -> String {
        "/tmp/atomic-test-\(Int.random(in: 0..<Int.max)).\(ext)"
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath)
        }
    }

    // MARK: - Basic write

    @Test("Write and read back bytes")
    func writeAndReadBytes() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let testData: [UInt8] = [72, 101, 108, 108, 111]  // "Hello"

        try File.System.Write.Atomic.write(testData, to: File.Path(path))

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == testData)
    }

    @Test("Write empty file")
    func emptyFileWrite() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        try File.System.Write.Atomic.write([], to: File.Path(path))

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData.isEmpty)
    }

    @Test("Write binary data")
    func writeBinaryData() throws {
        let path = uniquePath(extension: "bin")
        defer { cleanup(path) }

        let binaryData: [UInt8] = [0x00, 0x01, 0xFF, 0xFE, 0x7F, 0x80]

        try File.System.Write.Atomic.write(binaryData, to: File.Path(path))

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == binaryData)
    }

    @Test("Write large file")
    func writeLargeFile() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        // 64KB of data
        let largeData = [UInt8](repeating: 0xAB, count: 64 * 1024)

        try File.System.Write.Atomic.write(largeData, to: File.Path(path))

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == largeData)
    }

    // MARK: - Path validation errors

    @Test("Invalid path - empty")
    func invalidPathEmpty() {
        let emptyPath: String = ""
        #expect(throws: File.Path.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: try File.Path(emptyPath))
        }
    }

    @Test("Invalid path - contains control characters")
    func invalidPathControlCharacters() {
        let invalidPath: String = "/tmp/test\0file.txt"
        #expect(throws: File.Path.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: try File.Path(invalidPath))
        }
    }

    // MARK: - Strategy: replaceExisting

    @Test("Replace existing file (default strategy)")
    func replaceExistingFile() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        // First write
        try File.System.Write.Atomic.write([1, 2, 3], to: File.Path(path))

        // Second write should replace
        let newData: [UInt8] = [4, 5, 6, 7, 8]
        try File.System.Write.Atomic.write(newData, to: File.Path(path))

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == newData)
    }

    @Test("Replace with explicit replaceExisting strategy")
    func explicitReplaceExisting() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        try File.System.Write.Atomic.write([1, 2, 3], to: File.Path(path))

        let options = File.System.Write.Atomic.Options(strategy: .replaceExisting)
        let newData: [UInt8] = [7, 8, 9]
        try File.System.Write.Atomic.write(newData, to: File.Path(path), options: options)

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == newData)
    }

    // MARK: - Strategy: noClobber

    @Test("NoClobber strategy prevents overwrite")
    func noClobberPreventsOverwrite() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        // First write should succeed
        try File.System.Write.Atomic.write([1, 2, 3], to: File.Path(path))

        // Second write with noClobber should fail
        let options = File.System.Write.Atomic.Options(strategy: .noClobber)
        #expect(throws: File.System.Write.Atomic.Error.self) {
            try File.System.Write.Atomic.write([4, 5, 6], to: File.Path(path), options: options)
        }

        // Original content should be preserved
        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == [1, 2, 3])
    }

    @Test("NoClobber allows writing to new file")
    func noClobberAllowsNewFile() throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let options = File.System.Write.Atomic.Options(strategy: .noClobber)
        let data: [UInt8] = [1, 2, 3]
        try File.System.Write.Atomic.write(data, to: File.Path(path), options: options)

        let readData = try File.System.Read.Full.read(from: File.Path(path))
        #expect(readData == data)
    }

    // MARK: - Options

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.System.Write.Atomic.Options()
        #expect(options.strategy == .replaceExisting)
        #expect(options.preservePermissions == true)  // Default is true
        #expect(options.preserveTimestamps == false)
        #expect(options.preserveOwnership == false)
        #expect(options.strictOwnership == false)
        #expect(options.preserveExtendedAttributes == false)
        #expect(options.preserveACLs == false)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            preservePermissions: false,
            preserveOwnership: true,
            strictOwnership: true,
            preserveTimestamps: true,
            preserveExtendedAttributes: true,
            preserveACLs: true
        )
        #expect(options.strategy == .noClobber)
        #expect(options.preservePermissions == false)
        #expect(options.preserveTimestamps == true)
        #expect(options.preserveOwnership == true)
        #expect(options.strictOwnership == true)
        #expect(options.preserveExtendedAttributes == true)
        #expect(options.preserveACLs == true)
    }

    // MARK: - Strategy enum

    @Test("Strategy enum values")
    func strategyEnumValues() {
        let replace = File.System.Write.Atomic.Strategy.replaceExisting
        let noClobber = File.System.Write.Atomic.Strategy.noClobber

        #expect(replace != noClobber)
        #expect(replace == .replaceExisting)
        #expect(noClobber == .noClobber)
    }

    // MARK: - Async variants

    @Test("Async write and read back")
    func asyncWriteAndReadBack() async throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let testData: [UInt8] = [10, 20, 30, 40, 50]

        let filePath = try File.Path(path)
        let bytes = testData
        try File.System.Write.Atomic.write(bytes.span, to: filePath)

        let readData = try File.System.Read.Full.read(from: try File.Path(path))
        #expect(readData == testData)
    }

    @Test("Async write with options")
    func asyncWriteWithOptions() async throws {
        let path = uniquePath()
        defer { cleanup(path) }

        let options = File.System.Write.Atomic.Options(strategy: .noClobber)
        let data: [UInt8] = [1, 2, 3]

        let filePath = try File.Path(path)
        try File.System.Write.Atomic.write(data.span, to: filePath, options: options)

        let readData = try File.System.Read.Full.read(from: try File.Path(path))
        #expect(readData == data)
    }

    // MARK: - Error descriptions

    @Test("parent missing error description")
    func parentMissingErrorDescription() {
        let parentError = File.System.Parent.Check.Error.missing(
            path: "/nonexistent/parent"
        )
        let error = File.System.Write.Atomic.Error.parent(parentError)
        #expect(error.description.contains("Parent directory"))
    }

    @Test("parent accessDenied error description")
    func parentAccessDeniedErrorDescription() {
        let parentError = File.System.Parent.Check.Error.accessDenied(path: "/root")
        let error = File.System.Write.Atomic.Error.parent(parentError)
        #expect(error.description.contains("Access denied"))
    }

    @Test("parent notDirectory error description")
    func parentNotDirectoryErrorDescription() {
        let parentError = File.System.Parent.Check.Error.notDirectory(
            path: "/tmp/file"
        )
        let error = File.System.Write.Atomic.Error.parent(parentError)
        #expect(error.description.contains("not a directory"))
    }

    @Test("tempFileCreationFailed error description")
    func tempFileCreationFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.tempFileCreationFailed(
            directory: "/tmp",
            code: .posix(28),
            message: "No space left on device"
        )
        #expect(error.description.contains("temp file"))
        #expect(error.description.contains("No space left on device"))
    }

    @Test("writeFailed error description")
    func writeFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.writeFailed(
            bytesWritten: 100,
            bytesExpected: 200,
            code: .posix(28),
            message: "No space left on device"
        )
        #expect(error.description.contains("Write failed"))
        #expect(error.description.contains("100"))
        #expect(error.description.contains("200"))
    }

    @Test("syncFailed error description")
    func syncFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.syncFailed(code: .posix(5), message: "I/O error")
        #expect(error.description.contains("Sync failed"))
        #expect(error.description.contains("I/O error"))
    }

    @Test("closeFailed error description")
    func closeFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.closeFailed(
            code: .posix(9),
            message: "Bad file descriptor"
        )
        #expect(error.description.contains("Close failed"))
        #expect(error.description.contains("Bad file descriptor"))
    }

    @Test("metadataPreservationFailed error description")
    func metadataPreservationFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.metadataPreservationFailed(
            operation: "chown",
            code: .posix(1),
            message: "Operation not permitted"
        )
        #expect(error.description.contains("Metadata preservation failed"))
        #expect(error.description.contains("chown"))
    }

    @Test("destinationExists error description")
    func destinationExistsErrorDescription() {
        let error = File.System.Write.Atomic.Error.destinationExists(path: "/tmp/existing.txt")
        #expect(error.description.contains("already exists"))
        #expect(error.description.contains("/tmp/existing.txt"))
    }

    @Test("renameFailed error description")
    func renameFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.renameFailed(
            from: "/tmp/src",
            to: "/tmp/dst",
            code: .posix(18),
            message: "Cross-device link"
        )
        #expect(error.description.contains("Rename failed"))
        #expect(error.description.contains("/tmp/src"))
        #expect(error.description.contains("/tmp/dst"))
    }

    @Test("directorySyncFailed error description")
    func directorySyncFailedErrorDescription() {
        let error = File.System.Write.Atomic.Error.directorySyncFailed(
            path: "/tmp",
            code: .posix(5),
            message: "I/O error"
        )
        #expect(error.description.contains("Directory sync failed"))
        #expect(error.description.contains("/tmp"))
    }
}

// MARK: - Performance Tests

extension File.System.Write.Atomic.Test.Performance {

    @Test("File.System.Write.Atomic.write (1MB)", .timed(iterations: 10, warmup: 2))
    func systemWrite1MB() throws {
        let td = try tempDir()
        let filePath = File.Path(
            td,
            appending: "perf_syswrite_\(Int.random(in: 0..<Int.max)).bin"
        )

        defer { try? File.System.Delete.delete(at: filePath) }

        let oneMB = [UInt8](repeating: 0xEF, count: 1_000_000)
        try File.System.Write.Atomic.write(oneMB.span, to: filePath)
    }
}
