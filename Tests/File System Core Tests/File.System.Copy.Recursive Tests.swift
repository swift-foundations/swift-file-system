//
//  File.System.Copy.Recursive Tests.swift
//  swift-file-system
//
//  Created by Claude Code on 13/01/2026.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

// MARK: - Test Suite for recursive copy

@Suite("File.System.Copy.recursive")
struct CopyRecursiveTests {
    // MARK: - Basic Copy

    @Test
    func `Copy empty directory`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))
            #expect((try? File.System.Stat.info(at: destPath))?.type == .directory)
        }
    }

    @Test
    func `Copy directory with single file`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)
            let filePath = sourcePath / "test.txt"
            try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: filePath)

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let copiedFile = destPath / "test.txt"
            #expect(File.System.Stat.exists(at: copiedFile))

            let copiedData = try File.System.Read.Full.read(from: copiedFile) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(copiedData == [1, 2, 3, 4, 5])
        }
    }

    @Test
    func `Copy directory with nested subdirectories`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            // Create structure: source/a/b/c.txt
            let dirA = sourcePath / "a"
            let dirB = dirA / "b"

            try File.System.Create.Directory.create(
                at: dirB,
                createIntermediates: true
            )

            let filePath = dirB / "c.txt"
            try File.System.Write.Atomic.write([10, 20, 30].span, to: filePath)

            // Also add a file at root level
            let rootFile = sourcePath / "root.txt"
            try File.System.Write.Atomic.write([99].span, to: rootFile)

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            // Verify structure
            #expect(File.System.Stat.exists(at: destPath))
            #expect(File.System.Stat.exists(at: destPath / "a"))
            #expect(File.System.Stat.exists(at: destPath / "a" / "b"))
            #expect(File.System.Stat.exists(at: destPath / "a" / "b" / "c.txt"))
            #expect(File.System.Stat.exists(at: destPath / "root.txt"))

            // Verify file contents
            let copiedData = try File.System.Read.Full.read(from: destPath / "a" / "b" / "c.txt") { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(copiedData == [10, 20, 30])

            let rootData = try File.System.Read.Full.read(from: destPath / "root.txt") { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(rootData == [99])
        }
    }

    @Test
    func `Copy preserves source directory`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)
            let filePath = sourcePath / "test.txt"
            try File.System.Write.Atomic.write([1, 2, 3].span, to: filePath)

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            // Source should still exist
            #expect(File.System.Stat.exists(at: sourcePath))
            #expect(File.System.Stat.exists(at: filePath))
        }
    }

    // MARK: - Options

    @Test
    func `Copy with overwrite option`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            // Create source with file
            try File.System.Create.Directory.create(at: sourcePath)
            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath / "new.txt")

            // Create existing destination with different file
            try File.System.Create.Directory.create(at: destPath)
            try File.System.Write.Atomic.write([99].span, to: destPath / "old.txt")

            // Copy with overwrite
            let options = File.System.Copy.Options(overwrite: true)
            try File.System.Copy.recursive(from: sourcePath, to: destPath, options: options)

            // New file should exist, old file should not
            #expect(File.System.Stat.exists(at: destPath / "new.txt"))
            #expect(!File.System.Stat.exists(at: destPath / "old.txt"))
        }
    }

    @Test
    func `Copy without overwrite throws when destination exists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)
            try File.System.Create.Directory.create(at: destPath)

            let options = File.System.Copy.Options(overwrite: false)
            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.recursive(from: sourcePath, to: destPath, options: options)
            }
        }
    }

    @Test
    func `Options default values`() {
        let options = File.System.Copy.Options()
        #expect(options.overwrite == false)
        #expect(options.copyAttributes == true)
        #expect(options.followSymlinks == true)
    }

    // MARK: - Error Cases

    @Test
    func `Copy non-existent source throws sourceNotFound`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "non-existent"
            let destPath = dir.path / "dest"

            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.recursive(from: sourcePath, to: destPath)
            }
        }
    }

    @Test
    func `Copy to existing directory without overwrite throws destinationExists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)
            try File.System.Create.Directory.create(at: destPath)

            #expect(throws: File.System.Copy.Error.destinationExists) {
                try File.System.Copy.recursive(from: sourcePath, to: destPath)
            }
        }
    }

    // MARK: - File Fallback

    @Test
    func `Copy file delegates to file copy`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.txt"
            let destPath = dir.path / "dest.txt"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            // Recursive copy should work on files too
            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))
            let data = try File.System.Read.Full.read(from: destPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [1, 2, 3])
        }
    }

    // MARK: - Edge Cases

    @Test
    func `Copy directory with many files`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            try File.System.Create.Directory.create(at: sourcePath)

            // Create 10 files
            for i in 0..<10 {
                let filePath = sourcePath / "file\(i).txt"
                let bytes: [Byte] = [Byte(UInt8(i))]
                try File.System.Write.Atomic.write(bytes.span, to: filePath)
            }

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            // Verify all files copied
            for i in 0..<10 {
                let filePath = destPath / "file\(i).txt"
                #expect(File.System.Stat.exists(at: filePath))
                let data = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(data == [Byte(UInt8(i))])
            }
        }
    }

    @Test
    func `Copy deeply nested directory structure`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source"
            let destPath = dir.path / "dest"

            // Create deep structure: source/1/2/3/4/5/file.txt
            var currentPath = sourcePath
            for i in 1...5 {
                let component: File.Path.Component = "\(i)"
                currentPath = currentPath.appending(component)
            }

            try File.System.Create.Directory.create(
                at: currentPath,
                createIntermediates: true
            )
            try File.System.Write.Atomic.write([42].span, to: currentPath / "file.txt")

            try File.System.Copy.recursive(from: sourcePath, to: destPath)

            // Verify deep file exists
            var destFile = destPath
            for component: File.Path.Component in ["1", "2", "3", "4", "5", "file.txt"] {
                destFile = destFile.appending(component)
            }
            #expect(File.System.Stat.exists(at: destFile))
        }
    }
}
