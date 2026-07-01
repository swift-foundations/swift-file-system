//
//  File.System.Write.Atomic Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Atomic {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Atomic.Test.Unit {

    // MARK: - Basic write

    @Test
    func `Write and read back bytes`() throws {
        try File.Directory.temporary { dir in
            let testData: [Byte] = [72, 101, 108, 108, 111]  // "Hello"
            let path = dir.path / "test.txt"

            try File.System.Write.Atomic.write(testData, to: path)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == testData)
        }
    }

    @Test
    func `Write empty file`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "empty.txt"

            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty, to: path)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData.isEmpty)
        }
    }

    @Test
    func `Write binary data`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            let binaryData: [Byte] = [0x00, 0x01, 0xFF, 0xFE, 0x7F, 0x80]

            try File.System.Write.Atomic.write(binaryData, to: path)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == binaryData)
        }
    }

    @Test
    func `Write large file`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "large.txt"
            // 64KB of data
            let largeData = [Byte](repeating: 0xAB, count: 64 * 1024)

            try File.System.Write.Atomic.write(largeData, to: path)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == largeData)
        }
    }

    // MARK: - Path validation errors

    @Test
    func `Invalid path - empty`() {
        let emptyPath: Swift.String = ""
        #expect(throws: File.Path.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: try File.Path(emptyPath))
        }
    }

    @Test
    func `Invalid path - contains control characters`() {
        let invalidPath: Swift.String = "/tmp/test\0file.txt"
        #expect(throws: File.Path.Error.self) {
            try File.System.Write.Atomic.write([1, 2, 3], to: try File.Path(invalidPath))
        }
    }

    // MARK: - Strategy: replaceExisting

    #if !os(Windows)
        // Windows atomic rename with MOVEFILE_REPLACE_EXISTING can fail intermittently
        // with ACCESS_DENIED (error 5) due to filesystem delays releasing the target file.

        @Test
        func `Replace existing file (default strategy)`() throws {
            try File.Directory.temporary { dir in
                let path = dir.path / "replace.txt"

                // First write
                try File.System.Write.Atomic.write([1, 2, 3], to: path)

                // Second write should replace
                let newData: [Byte] = [4, 5, 6, 7, 8]
                try File.System.Write.Atomic.write(newData, to: path)

                let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readData == newData)
            }
        }

        @Test
        func `Replace with explicit replaceExisting strategy`() throws {
            try File.Directory.temporary { dir in
                let path = dir.path / "explicit.txt"

                try File.System.Write.Atomic.write([1, 2, 3], to: path)

                let options = File.System.Write.Atomic.Options(strategy: .replaceExisting)
                let newData: [Byte] = [7, 8, 9]
                try File.System.Write.Atomic.write(newData, to: path, options: options)

                let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readData == newData)
            }
        }
    #endif

    // MARK: - Strategy: noClobber

    @Test
    func `NoClobber strategy prevents overwrite`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "noclobber.txt"

            // First write should succeed
            try File.System.Write.Atomic.write([1, 2, 3], to: path)

            // Second write with noClobber should fail
            let options = File.System.Write.Atomic.Options(strategy: .noClobber)
            #expect(throws: File.System.Write.Atomic.Error.self) {
                try File.System.Write.Atomic.write([4, 5, 6], to: path, options: options)
            }

            // Original content should be preserved
            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [1, 2, 3])
        }
    }

    @Test
    func `NoClobber allows writing to new file`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "newfile.txt"

            let options = File.System.Write.Atomic.Options(strategy: .noClobber)
            let data: [Byte] = [1, 2, 3]
            try File.System.Write.Atomic.write(data, to: path, options: options)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == data)
        }
    }

    // MARK: - Options

    @Test
    func `Options default values`() {
        let options = File.System.Write.Atomic.Options()
        #expect(options.strategy == .replaceExisting)
        #expect(options.preservation == .permissions)
        #expect(options.ownership == .ignore)
    }

    @Test
    func `Options custom values`() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            preservation: [.timestamps, .extendedAttributes, .acls],
            ownership: .preserve(strict: true)
        )
        #expect(options.strategy == .noClobber)
        #expect(!options.preservation.contains(.permissions))
        #expect(options.preservation.contains(.timestamps))
        #expect(options.preservation.contains(.extendedAttributes))
        #expect(options.preservation.contains(.acls))
        #expect(options.ownership == .preserve(strict: true))
    }

    // MARK: - Strategy enum

    @Test
    func `Strategy enum values`() {
        let replace = File.System.Write.Atomic.Strategy.replaceExisting
        let noClobber = File.System.Write.Atomic.Strategy.noClobber

        #expect(replace != noClobber)
        #expect(replace == .replaceExisting)
        #expect(noClobber == .noClobber)
    }

    // MARK: - Async variants

    @Test
    func `Async write and read back`() async throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "async.txt"
            let testData: [Byte] = [10, 20, 30, 40, 50]

            let bytes = testData
            try File.System.Write.Atomic.write(bytes.span, to: path)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == testData)
        }
    }

    @Test
    func `Async write with options`() async throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "asyncopt.txt"

            let options = File.System.Write.Atomic.Options(strategy: .noClobber)
            let data: [Byte] = [1, 2, 3]

            try File.System.Write.Atomic.write(data.span, to: path, options: options)

            let readData = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == data)
        }
    }

    // MARK: - Error descriptions

    @Test
    func `parentVerificationFailed error description`() {
        let error = File.System.Write.Atomic.Error.parentVerificationFailed(
            path: "/nonexistent/parent",
            code: .posix(2),
            message: "No such file or directory"
        )
        #expect(error.description.contains("Parent directory"))
    }

    @Test
    func `tempFileCreationFailed error description`() {
        let error = File.System.Write.Atomic.Error.tempFileCreationFailed(
            directory: "/tmp",
            code: .posix(28),
            message: "No space left on device"
        )
        #expect(error.description.contains("temp file"))
        #expect(error.description.contains("No space left on device"))
    }

    @Test
    func `writeFailed error description`() {
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

    @Test
    func `syncFailed error description`() {
        let error = File.System.Write.Atomic.Error.syncFailed(code: .posix(5), message: "I/O error")
        #expect(error.description.contains("Sync failed"))
        #expect(error.description.contains("I/O error"))
    }

    @Test
    func `closeFailed error description`() {
        let error = File.System.Write.Atomic.Error.closeFailed(
            code: .posix(9),
            message: "Bad file descriptor"
        )
        #expect(error.description.contains("Close failed"))
        #expect(error.description.contains("Bad file descriptor"))
    }

    @Test
    func `metadataPreservationFailed error description`() {
        let error = File.System.Write.Atomic.Error.metadataPreservationFailed(
            operation: "chown",
            code: .posix(1),
            message: "Operation not permitted"
        )
        #expect(error.description.contains("Metadata preservation failed"))
        #expect(error.description.contains("chown"))
    }

    @Test
    func `destinationExists error description`() {
        let path: File.Path = "/tmp/existing.txt"
        let error = File.System.Write.Atomic.Error.destinationExists(path: path)
        #expect(error.description.contains("already exists"))
        #expect(error.description.contains(Swift.String(path)))
    }

    @Test
    func `renameFailed error description`() {
        let srcPath: File.Path = "/tmp/src"
        let dstPath: File.Path = "/tmp/dst"
        let error = File.System.Write.Atomic.Error.renameFailed(
            from: srcPath,
            to: dstPath,
            code: .posix(18),
            message: "Cross-device link"
        )
        #expect(error.description.contains("Rename failed"))
        #expect(error.description.contains(Swift.String(srcPath)))
        #expect(error.description.contains(Swift.String(dstPath)))
    }

    @Test
    func `directorySyncFailed error description`() {
        let path: File.Path = "/tmp"
        let error = File.System.Write.Atomic.Error.directorySyncFailed(
            path: path,
            code: .posix(5),
            message: "I/O error"
        )
        #expect(error.description.contains("Directory sync failed"))
        #expect(error.description.contains(Swift.String(path)))
    }
}

// MARK: - createIntermediates tests

extension File.System.Write.Atomic.Test.Integration {

    @Test
    func `createIntermediates creates directories with execute bit`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "subdir" / "file.txt"

            try File.System.Write.Atomic.write([1, 2, 3], to: nested, createIntermediates: true)

            // Verify file was written
            let readData = try File.System.Read.Full.read(from: nested) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            #expect(readData == [1, 2, 3])

            // Verify parent directory has correct permissions (execute bit set)
            let parentPath = dir.path / "subdir"
            let permissions = try File.System.Metadata.Permissions(at: parentPath)
            #expect(
                permissions.contains(.ownerExecute),
                "Created directory must have owner execute bit for traversal"
            )
            #expect(
                permissions.contains(.ownerRead),
                "Created directory must have owner read bit for listing"
            )
        }
    }

    @Test
    func `createIntermediates allows subsequent file creation in same directory`() throws {
        try File.Directory.temporary { dir in
            let first = dir.path / "newdir" / "first.txt"
            let second = dir.path / "newdir" / "second.txt"

            try File.System.Write.Atomic.write([1], to: first, createIntermediates: true)
            try File.System.Write.Atomic.write([2], to: second, createIntermediates: true)

            let firstData = try File.System.Read.Full.read(from: first) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            let secondData = try File.System.Read.Full.read(from: second) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            #expect(firstData == [1])
            #expect(secondData == [2])
        }
    }

    @Test
    func `createIntermediates creates multiple levels of directories`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "a" / "b" / "c" / "file.txt"

            try File.System.Write.Atomic.write([1, 2, 3], to: nested, createIntermediates: true)

            let readData = try File.System.Read.Full.read(from: nested) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            #expect(readData == [1, 2, 3])
        }
    }

    @Test
    func `default createIntermediates false throws for missing parent`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "nonexistent" / "file.txt"

            #expect(throws: File.System.Write.Atomic.Error.self) {
                try File.System.Write.Atomic.write([1, 2, 3], to: nested)
            }
        }
    }

    @Test
    func `createIntermediates preserves existing directories`() throws {
        try File.Directory.temporary { dir in
            let subdir = dir.path / "existing"
            try File.System.Create.Directory.create(at: subdir)
            let existingFile = subdir / "old.txt"
            try File.System.Write.Atomic.write([1], to: existingFile)

            // Write a new file with createIntermediates into the same directory
            let newFile = subdir / "new.txt"
            try File.System.Write.Atomic.write([2], to: newFile, createIntermediates: true)

            // Both files should exist
            let oldData = try File.System.Read.Full.read(from: existingFile) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            let newData = try File.System.Read.Full.read(from: newFile) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            #expect(oldData == [1])
            #expect(newData == [2])
        }
    }

    @Test
    func `createIntermediates works with noClobber strategy`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "a" / "b" / "file.txt"
            let options = File.System.Write.Atomic.Options(strategy: .noClobber)

            try File.System.Write.Atomic.write([1, 2, 3], to: nested, options: options, createIntermediates: true)

            let readData = try File.System.Read.Full.read(from: nested) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            #expect(readData == [1, 2, 3])
        }
    }

    @Test
    func `createIntermediates is independent of Options`() throws {
        try File.Directory.temporary { dir in
            // Test with different Options configurations to verify orthogonality
            let configurations: [(File.System.Write.Atomic.Options, File.Path.Component)] = [
                (.init(strategy: .replaceExisting, durability: .full), "replaceExisting-full"),
                (.init(strategy: .noClobber, durability: .dataOnly), "noClobber-dataOnly"),
                (.init(strategy: .replaceExisting, durability: .none), "replaceExisting-none"),
            ]

            for (options, name) in configurations {
                let nested = dir.path / name / "file.txt"
                try File.System.Write.Atomic.write([1], to: nested, options: options, createIntermediates: true)

                let readData = try File.System.Read.Full.read(from: nested) {
                    $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
                }
                #expect(readData == [1], "Failed for configuration: \(name)")
            }
        }
    }
}
