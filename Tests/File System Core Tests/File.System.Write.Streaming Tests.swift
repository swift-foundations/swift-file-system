//
//  File.System.Write.Streaming Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Streaming.Test.Unit {

    // MARK: - Basic Streaming Write

    @Test
    func `Write multiple chunks and read back`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [
                [72, 101, 108, 108, 111],  // "Hello"
                [32],  // " "
                [87, 111, 114, 108, 100],  // "World"
            ]

            let filePath = dir.path / "test.txt"
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100])
        }
    }

    @Test
    func `Write empty chunks array`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = []

            let filePath = dir.path / "test.txt"
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData.isEmpty)
        }
    }

    @Test
    func `Write single chunk`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [[1, 2, 3, 4, 5]]

            let filePath = dir.path / "test.txt"
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [1, 2, 3, 4, 5])
        }
    }

    @Test
    func `Write chunks with empty chunk in middle`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [
                [1, 2, 3],
                [],  // Empty chunk
                [4, 5, 6],
            ]

            let filePath = dir.path / "test.txt"
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test
    func `Write large file in chunks`() throws {
        try File.Directory.temporary { dir in
            // 256KB total in 64KB chunks
            let chunkSize = 64 * 1024
            let chunks: [[Byte]] = (0..<4).map { i in
                [Byte](repeating: Byte(UInt8(truncatingIfNeeded: i)), count: chunkSize)
            }

            let filePath = dir.path / "test.bin"
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData.count == 4 * chunkSize)
        }
    }

    // MARK: - Lazy Swift.Sequence Support

    @Test
    func `Write from lazy sequence`() throws {
        try File.Directory.temporary { dir in
            // Lazy sequence that generates chunks on demand
            let lazyChunks = (0..<3).lazy.map { i -> [Byte] in
                [Byte](repeating: Byte(UInt8(i)), count: 10)
            }

            let filePath = dir.path / "test.bin"
            try File.System.Write.Streaming.write(lazyChunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData.count == 30)
            #expect(readData[0..<10] == ArraySlice([Byte](repeating: 0, count: 10)))
            #expect(readData[10..<20] == ArraySlice([Byte](repeating: 1, count: 10)))
            #expect(readData[20..<30] == ArraySlice([Byte](repeating: 2, count: 10)))
        }
    }

    // MARK: - CommitPolicy Tests

    @Test
    func `Atomic write (default) creates file`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [[1, 2, 3]]
            let filePath = dir.path / "test.txt"

            // Default is atomic
            try File.System.Write.Streaming.write(chunks, to: filePath)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [1, 2, 3])
        }
    }

    @Test
    func `Atomic write with explicit options`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [[4, 5, 6]]
            let filePath = dir.path / "test.txt"

            let options = File.System.Write.Streaming.Options(
                commit: .atomic(.init(durability: .full))
            )
            try File.System.Write.Streaming.write(chunks, to: filePath, options: options)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [4, 5, 6])
        }
    }

    @Test
    func `Direct write creates file`() throws {
        try File.Directory.temporary { dir in
            let chunks: [[Byte]] = [[7, 8, 9]]
            let filePath = dir.path / "test.txt"

            let options = File.System.Write.Streaming.Options(
                commit: .direct(.init(strategy: .truncate))
            )
            try File.System.Write.Streaming.write(chunks, to: filePath, options: options)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [7, 8, 9])
        }
    }

    // MARK: - Strategy Tests

    @Test
    func `Atomic noClobber prevents overwrite`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"

            // First write
            try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath)

            // Second write with noClobber should fail
            let options = File.System.Write.Streaming.Options(
                commit: .atomic(.init(strategy: .noClobber))
            )
            #expect(throws: File.System.Write.Streaming.Error.self) {
                try File.System.Write.Streaming.write([[4, 5, 6]], to: filePath, options: options)
            }

            // Original content preserved
            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [1, 2, 3])
        }
    }

    @Test
    func `Direct create strategy prevents overwrite`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"

            // First write
            let createOptions = File.System.Write.Streaming.Options(
                commit: .direct(.init(strategy: .truncate))
            )
            try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath, options: createOptions)

            // Second write with create strategy should fail
            let options = File.System.Write.Streaming.Options(
                commit: .direct(.init(strategy: .create))
            )
            #expect(throws: File.System.Write.Streaming.Error.self) {
                try File.System.Write.Streaming.write([[4, 5, 6]], to: filePath, options: options)
            }
        }
    }

    @Test
    func `Direct truncate replaces existing`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"

            // First write
            try File.System.Write.Streaming.write([[1, 2, 3]], to: filePath)

            // Second write with truncate should succeed
            let options = File.System.Write.Streaming.Options(
                commit: .direct(.init(strategy: .truncate))
            )
            try File.System.Write.Streaming.write([[4, 5, 6, 7]], to: filePath, options: options)

            let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readData == [4, 5, 6, 7])
        }
    }

    // MARK: - Error Tests

    @Test
    func `parentNotFound error for invalid path`() {
        #expect(throws: File.System.Write.Streaming.Error.self) {
            let chunks: [[Byte]] = [[1, 2, 3]]
            let filePath = File.Path("/nonexistent/directory/file.txt")
            try File.System.Write.Streaming.write(chunks, to: filePath)
        }
    }

    // MARK: - Error Descriptions

    @Test
    func `parentVerificationFailed error description`() {
        let error = File.System.Write.Streaming.Error.parentVerificationFailed(
            path: "/nonexistent/parent",
            code: .posix(2),
            message: "No such file or directory"
        )
        #expect(error.description.contains("Parent directory"))
    }

    @Test
    func `destinationExists error description`() {
        let error = File.System.Write.Streaming.Error.destinationExists(
            path: "/tmp/existing.txt"
        )
        #expect(error.description.contains("already exists"))
    }

    @Test
    func `writeFailed error description`() {
        let error = File.System.Write.Streaming.Error.writeFailed(
            bytesWritten: 100,
            code: .posix(28),
            message: "No space left on device"
        )
        #expect(error.description.contains("Write failed"))
        #expect(error.description.contains("100"))
    }

    // MARK: - Options Tests

    @Test
    func `Default options use atomic commit`() {
        let options = File.System.Write.Streaming.Options()
        if case .atomic = options.commit {
            // Expected
        } else {
            Issue.record("Default commit should be atomic")
        }
    }

    @Test
    func `Direct.Options default values`() {
        let options = File.System.Write.Streaming.Direct.Options()
        #expect(options.strategy == .truncate)
        #expect(options.durability == .full)
    }

    @Test
    func `Direct.Options custom values`() {
        let options = File.System.Write.Streaming.Direct.Options(
            strategy: .create,
            durability: .dataOnly
        )
        #expect(options.strategy == .create)
        #expect(options.durability == .dataOnly)
    }

    @Test
    func `Atomic.Options default values`() {
        let options = File.System.Write.Streaming.Atomic.Options()
        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
    }

    @Test
    func `Atomic.Options custom values`() {
        let options = File.System.Write.Streaming.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly
        )
        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
    }

    @Test
    func `durabilityNotGuaranteed error description`() {
        let error = File.System.Write.Streaming.Error.durabilityNotGuaranteed(
            path: "/tmp/test.txt",
            reason: "Task was cancelled"
        )
        #expect(error.description.contains("durability not guaranteed"))
        #expect(error.description.contains("cancelled"))
    }

    @Test
    func `directorySyncFailedAfterCommit error description`() {
        let error = File.System.Write.Streaming.Error.directorySyncFailedAfterCommit(
            path: "/tmp/test.txt",
            code: .posix(5),
            message: "I/O error"
        )
        #expect(error.description.contains("Directory sync failed after commit"))
        #expect(error.description.contains("I/O error"))
    }
}

// MARK: - createIntermediates tests

extension File.System.Write.Streaming.Test.Integration {

    @Test
    func `createIntermediates creates directories with execute bit`() throws {
        try File.Directory.temporary { dir in
            let nested = dir.path / "subdir" / "file.txt"

            try File.System.Write.Streaming.write([[1, 2, 3]], to: nested, createIntermediates: true)

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

            try File.System.Write.Streaming.write([[1]], to: first, createIntermediates: true)
            try File.System.Write.Streaming.write([[2]], to: second, createIntermediates: true)

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

            try File.System.Write.Streaming.write([[1, 2, 3]], to: nested, createIntermediates: true)

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

            #expect(throws: File.System.Write.Streaming.Error.self) {
                try File.System.Write.Streaming.write([[1, 2, 3]], to: nested)
            }
        }
    }

    @Test
    func `createIntermediates preserves existing directories`() throws {
        try File.Directory.temporary { dir in
            let subdir = dir.path / "existing"
            try File.System.Create.Directory.create(at: subdir)
            let existingFile = subdir / "old.txt"
            try File.System.Write.Streaming.write([[1]], to: existingFile)

            // Write a new file with createIntermediates into the same directory
            let newFile = subdir / "new.txt"
            try File.System.Write.Streaming.write([[2]], to: newFile, createIntermediates: true)

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
            let options = File.System.Write.Streaming.Options(
                commit: .atomic(.init(strategy: .noClobber))
            )

            try File.System.Write.Streaming.write([[1, 2, 3]], to: nested, options: options, createIntermediates: true)

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
            let configurations: [(File.System.Write.Streaming.Options, File.Path.Component)] = [
                (.init(commit: .atomic(.init(durability: .full))), "atomic-full"),
                (.init(commit: .atomic(.init(strategy: .noClobber, durability: .dataOnly))), "atomic-noClobber-dataOnly"),
                (.init(commit: .direct(.init(strategy: .truncate))), "direct-truncate"),
            ]

            for (options, name) in configurations {
                let nested = dir.path / name / "file.txt"
                try File.System.Write.Streaming.write([[1]], to: nested, options: options, createIntermediates: true)

                let readData = try File.System.Read.Full.read(from: nested) {
                    $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
                }
                #expect(readData == [1], "Failed for configuration: \(name)")
            }
        }
    }
}
