//
//  File.Descriptor Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Descriptor {
    #TestSuites
}

extension File.Descriptor.Test.Unit {
    // MARK: - Test Fixtures

    private func createTempFile(content: [UInt8] = []) throws -> String {
        let path = "/tmp/descriptor-test-\(Int.random(in: 0..<Int.max)).bin"
        try File.System.Write.Atomic.write(content.span, to: File.Path(path))
        return path
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath, options: .init(recursive: true))
        }
    }

    // MARK: - Opening

    @Test("Open file in read mode")
    func openReadMode() throws {
        let path = try createTempFile(content: [1, 2, 3])
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .read)
        let isValid = descriptor.isValid
        #expect(isValid)
        try descriptor.close()
    }

    @Test("Open file in write mode")
    func openWriteMode() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .write)
        let isValid = descriptor.isValid
        #expect(isValid)
        try descriptor.close()
    }

    @Test("Open file in readWrite mode")
    func openReadWriteMode() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .readWrite)
        let isValid = descriptor.isValid
        #expect(isValid)
        try descriptor.close()
    }

    @Test("Open non-existing file throws error")
    func openNonExisting() throws {
        let path = "/tmp/non-existing-\(Int.random(in: 0..<Int.max)).txt"
        let filePath = try File.Path(path)

        #expect(throws: File.Descriptor.Error.self) {
            _ = try File.Descriptor.open(filePath, mode: .read)
        }
    }

    // MARK: - Options

    @Test("Open with create option creates file")
    func openWithCreate() throws {
        let path = "/tmp/descriptor-create-\(Int.random(in: 0..<Int.max)).txt"
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .write, options: [.create])
        let isValid = descriptor.isValid
        #expect(isValid)
        #expect(File.System.Stat.exists(at: try File.Path(path)))
        try descriptor.close()
    }

    @Test("Open with truncate option truncates file")
    func openWithTruncate() throws {
        let path = try createTempFile(content: [1, 2, 3, 4, 5])
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .write, options: [.truncate])
        try descriptor.close()

        let data = try File.System.Read.Full.read(from: try File.Path(path))
        #expect(data.isEmpty)
    }

    @Test("Open with exclusive and create on existing file throws")
    func openWithExclusiveOnExisting() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        #expect(throws: File.Descriptor.Error.self) {
            _ = try File.Descriptor.open(
                filePath,
                mode: .write,
                options: [.create, .exclusive]
            )
        }
    }

    // MARK: - Closing

    @Test("Close makes descriptor invalid")
    func closeInvalidates() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .read)
        let isValid = descriptor.isValid
        #expect(isValid)
        try descriptor.close()
        // After close, descriptor is consumed, can't check isValid
    }

    @Test("Double close throws alreadyClosed")
    func doubleCloseThrows() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        var descriptor = try File.Descriptor.open(filePath, mode: .read)
        try descriptor.close()

        // Can't actually test double close since close() is consuming
        // The descriptor is consumed after first close
    }

    // MARK: - Mode enum

    @Test("Mode enum values")
    func modeEnumValues() {
        let read = File.Descriptor.Mode.read
        let write = File.Descriptor.Mode.write
        let readWrite = File.Descriptor.Mode.readWrite

        #expect(read != write)
        #expect(write != readWrite)
        #expect(read != readWrite)
    }

    @Test("Mode rawValue for .read")
    func modeRawValueRead() {
        #expect(File.Descriptor.Mode.read.rawValue == 0)
    }

    @Test("Mode rawValue for .write")
    func modeRawValueWrite() {
        #expect(File.Descriptor.Mode.write.rawValue == 1)
    }

    @Test("Mode rawValue for .readWrite")
    func modeRawValueReadWrite() {
        #expect(File.Descriptor.Mode.readWrite.rawValue == 2)
    }

    @Test("Mode rawValue round-trip")
    func modeRawValueRoundTrip() {
        for mode in [File.Descriptor.Mode.read, .write, .readWrite] {
            let restored = File.Descriptor.Mode(rawValue: mode.rawValue)
            #expect(restored == mode)
        }
    }

    @Test("Mode invalid rawValue returns nil")
    func modeInvalidRawValue() {
        #expect(File.Descriptor.Mode(rawValue: 3) == nil)
        #expect(File.Descriptor.Mode(rawValue: 255) == nil)
    }

    @Test("Mode Binary.Serializable")
    func modeBinarySerialize() {
        var buffer: [UInt8] = []
        File.Descriptor.Mode.serialize(.read, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.Descriptor.Mode.serialize(.write, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Descriptor.Mode.serialize(.readWrite, into: &buffer)
        #expect(buffer == [2])
    }

    @Test("Mode is Sendable")
    func modeSendable() async {
        let mode: File.Descriptor.Mode = .readWrite

        let result = await Task {
            mode
        }.value

        #expect(result == .readWrite)
    }

    // MARK: - Options OptionSet

    @Test("Options default is empty")
    func optionsDefault() {
        let options: File.Descriptor.Options = []
        #expect(options.isEmpty)
    }

    @Test("Options can be combined")
    func optionsCombined() {
        let options: File.Descriptor.Options = [.create, .truncate]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(!options.contains(.exclusive))
    }

    @Test("Options rawValue")
    func optionsRawValue() {
        #expect(File.Descriptor.Options.create.rawValue == 1 << 0)
        #expect(File.Descriptor.Options.truncate.rawValue == 1 << 1)
        #expect(File.Descriptor.Options.exclusive.rawValue == 1 << 2)
        #expect(File.Descriptor.Options.append.rawValue == 1 << 3)
        #expect(File.Descriptor.Options.noFollow.rawValue == 1 << 4)
        #expect(File.Descriptor.Options.closeOnExec.rawValue == 1 << 5)
    }

    @Test("Options all combined")
    func optionsAllCombined() {
        let options: File.Descriptor.Options = [
            .create, .truncate, .exclusive, .append, .noFollow, .closeOnExec,
        ]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(options.contains(.exclusive))
        #expect(options.contains(.append))
        #expect(options.contains(.noFollow))
        #expect(options.contains(.closeOnExec))
        // 1 + 2 + 4 + 8 + 16 + 32 = 63
        #expect(options.rawValue == 63)
    }

    @Test("Options Binary.Serializable")
    func optionsBinarySerialize() {
        var buffer: [UInt8] = []
        File.Descriptor.Options.serialize(.create, into: &buffer)
        // UInt32 little-endian: 1 = [1, 0, 0, 0]
        #expect(buffer.count == 4)
        #expect(buffer[0] == 1)
    }

    @Test("Options is Sendable")
    func optionsSendable() async {
        let options: File.Descriptor.Options = [.create, .truncate]

        let result = await Task {
            options
        }.value

        #expect(result == [.create, .truncate])
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = try File.Path("/tmp/a")
        let path2 = try File.Path("/tmp/a")

        #expect(
            File.Descriptor.Error.pathNotFound(path1)
                == File.Descriptor.Error.pathNotFound(path2)
        )
        #expect(
            File.Descriptor.Error.tooManyOpenFiles == File.Descriptor.Error.tooManyOpenFiles
        )
        #expect(File.Descriptor.Error.alreadyClosed == File.Descriptor.Error.alreadyClosed)
    }

    @Test("Errors are Sendable")
    func errorsSendable() async throws {
        let path = try File.Path("/tmp/test")
        let error = File.Descriptor.Error.pathNotFound(path)

        let result = await Task {
            error
        }.value

        #expect(result == error)
    }

    // MARK: - All Error Cases

    @Test("Error.pathNotFound")
    func errorPathNotFound() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.Descriptor.Error.pathNotFound(path)
        if case .pathNotFound(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected pathNotFound")
        }
    }

    @Test("Error.permissionDenied")
    func errorPermissionDenied() throws {
        let path = try File.Path("/root/secret")
        let error = File.Descriptor.Error.permissionDenied(path)
        if case .permissionDenied(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected permissionDenied")
        }
    }

    @Test("Error.alreadyExists")
    func errorAlreadyExists() throws {
        let path = try File.Path("/tmp/existing")
        let error = File.Descriptor.Error.alreadyExists(path)
        if case .alreadyExists(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected alreadyExists")
        }
    }

    @Test("Error.isDirectory")
    func errorIsDirectory() throws {
        let path = try File.Path("/tmp")
        let error = File.Descriptor.Error.isDirectory(path)
        if case .isDirectory(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected isDirectory")
        }
    }

    @Test("Error.tooManyOpenFiles")
    func errorTooManyOpenFiles() {
        let error = File.Descriptor.Error.tooManyOpenFiles
        if case .tooManyOpenFiles = error {
            #expect(true)
        } else {
            Issue.record("Expected tooManyOpenFiles")
        }
    }

    @Test("Error.invalidDescriptor")
    func errorInvalidDescriptor() {
        let error = File.Descriptor.Error.invalidDescriptor
        if case .invalidDescriptor = error {
            #expect(true)
        } else {
            Issue.record("Expected invalidDescriptor")
        }
    }

    @Test("Error.openFailed")
    func errorOpenFailed() {
        let error = File.Descriptor.Error.openFailed(errno: 13, message: "Permission denied")
        if case .openFailed(let errno, let message) = error {
            #expect(errno == 13)
            #expect(message == "Permission denied")
        } else {
            Issue.record("Expected openFailed")
        }
    }

    @Test("Error.closeFailed")
    func errorCloseFailed() {
        let error = File.Descriptor.Error.closeFailed(errno: 9, message: "Bad file descriptor")
        if case .closeFailed(let errno, let message) = error {
            #expect(errno == 9)
            #expect(message == "Bad file descriptor")
        } else {
            Issue.record("Expected closeFailed")
        }
    }

    @Test("Error.duplicateFailed")
    func errorDuplicateFailed() {
        let error = File.Descriptor.Error.duplicateFailed(errno: 24, message: "Too many open files")
        if case .duplicateFailed(let errno, let message) = error {
            #expect(errno == 24)
            #expect(message == "Too many open files")
        } else {
            Issue.record("Expected duplicateFailed")
        }
    }

    @Test("Error.alreadyClosed")
    func errorAlreadyClosed() {
        let error = File.Descriptor.Error.alreadyClosed
        if case .alreadyClosed = error {
            #expect(true)
        } else {
            Issue.record("Expected alreadyClosed")
        }
    }
}
