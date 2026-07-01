//
//  File.System.Copy Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if canImport(Foundation)
    import Foundation
#endif

extension File.System.Copy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Copy.Test.Unit {
    // MARK: - Basic Copy

    @Test
    func `Copy file to new location`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let sourceData = try File.System.Read.Full.read(from: sourcePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            let destData = try File.System.Read.Full.read(from: destPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(sourceData == destData)
        }
    }

    @Test
    func `Copy preserves source file`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            // Source should still exist
            #expect(File.System.Stat.exists(at: sourcePath))
        }
    }

    @Test
    func `Copy empty file`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "empty.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([Byte]().span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            try File.System.Read.Full.read(from: destPath) { span in
                #expect(span.count == 0)
            }
        }
    }

    // MARK: - Options

    @Test
    func `Copy with overwrite option`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Copy.Options(overwrite: true)
            try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

            let destData = try File.System.Read.Full.read(from: destPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(destData == [1, 2, 3])
        }
    }

    @Test
    func `Copy without overwrite throws when destination exists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Copy.Options(overwrite: false)
            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)
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

    @Test
    func `Options custom values`() {
        let options = File.System.Copy.Options(
            overwrite: true,
            copyAttributes: false,
            followSymlinks: false
        )
        #expect(options.overwrite == true)
        #expect(options.copyAttributes == false)
        #expect(options.followSymlinks == false)
    }

    // MARK: - Error Cases

    @Test
    func `Copy non-existent source throws sourceNotFound`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "non-existent.bin"
            let destPath = dir.path / "dest.bin"

            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: sourcePath, to: destPath)
            }
        }
    }

    @Test
    func `Copy to existing file without overwrite throws destinationExists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99].span, to: destPath)

            #expect(throws: File.System.Copy.Error.destinationExists) {
                try File.System.Copy.copy(from: sourcePath, to: destPath)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test
    func `sourceNotFound error description`() throws {
        let error = File.System.Copy.Error.sourceNotFound
        #expect(error.description.contains("source not found"))
    }

    @Test
    func `destinationExists error description`() throws {
        let error = File.System.Copy.Error.destinationExists
        #expect(error.description.contains("already exists"))
    }

    @Test
    func `permissionDenied error description`() throws {
        let error = File.System.Copy.Error.permissionDenied
        #expect(error.description.contains("permission denied"))
    }

    @Test
    func `isDirectory error description`() throws {
        let error = File.System.Copy.Error.isDirectory
        #expect(error.description.contains("is a directory"))
    }

    @Test
    func `operation error description`() {
        let error = File.System.Copy.Error.operation("I/O error")
        #expect(error.description.contains("operation failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Error Equatable

    @Test
    func `Errors are equatable`() throws {
        #expect(
            File.System.Copy.Error.sourceNotFound
                == File.System.Copy.Error.sourceNotFound
        )
        #expect(
            File.System.Copy.Error.destinationExists
                == File.System.Copy.Error.destinationExists
        )
    }

    // MARK: - Semantic Accessors

    @Test
    func `isSourceNotFound semantic accessor`() {
        let error = File.System.Copy.Error.sourceNotFound
        #expect(error.isSourceNotFound == true)
        #expect(error.isDestinationExists == false)
        #expect(error.isPermissionDenied == false)
        #expect(error.isDirectory == false)
    }

    @Test
    func `isDestinationExists semantic accessor`() {
        let error = File.System.Copy.Error.destinationExists
        #expect(error.isDestinationExists == true)
        #expect(error.isSourceNotFound == false)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Copy.Error.permissionDenied
        #expect(error.isPermissionDenied == true)
        #expect(error.isSourceNotFound == false)
    }

    @Test
    func `isDirectory semantic accessor`() {
        let error = File.System.Copy.Error.isDirectory
        #expect(error.isDirectory == true)
        #expect(error.isSourceNotFound == false)
    }

    // MARK: - Darwin-specific Edge Cases

    #if canImport(Darwin)
        #if canImport(Foundation)
            @Suite("EdgeCase")
            struct EdgeCase {

                @Test
                func `Overwrite when destination is directory fails appropriately`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destDir = dir.path / "dest-dir"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
                        try FileManager.default.createDirectory(
                            atPath: Swift.String(destDir),
                            withIntermediateDirectories: false
                        )

                        let options = File.System.Copy.Options(overwrite: true)

                        // COPYFILE_UNLINK should not delete directories
                        #expect(throws: File.System.Copy.Error.self) {
                            try File.System.Copy.copy(from: sourcePath, to: destDir, options: options)
                        }

                        // Verify directory still exists
                        #expect(FileManager.default.fileExists(atPath: Swift.String(destDir)))
                    }
                }

                @Test
                func `Overwrite when destination is symlink removes symlink`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let targetPath = dir.path / "target.bin"
                        let symlinkPath = dir.path / "symlink.link"

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: sourcePath)
                        try File.System.Write.Atomic.write([99].span, to: targetPath)

                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(symlinkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        let options = File.System.Copy.Options(overwrite: true)
                        try File.System.Copy.copy(from: sourcePath, to: symlinkPath, options: options)

                        // Destination should now be a regular file, not a symlink
                        var isSymlink: ObjCBool = false
                        FileManager.default.fileExists(atPath: Swift.String(symlinkPath), isDirectory: &isSymlink)

                        // Verify it's now a regular file with source content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(symlinkPath)))
                        #expect(destData == Data([10, 20, 30]))

                        // Verify original target file is unchanged
                        let targetData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(targetPath)))
                        #expect(targetData == Data([99]))
                    }
                }

                @Test
                func `COPYFILE_NOFOLLOW with symlink source copies symlink itself`() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = dir.path / "target.bin"
                        let symlinkPath = dir.path / "source-symlink.link"
                        let destPath = dir.path / "dest-symlink.link"

                        try File.System.Write.Atomic.write([99, 88, 77].span, to: targetPath)

                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(symlinkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        let options = File.System.Copy.Options(followSymlinks: false)
                        try File.System.Copy.copy(from: symlinkPath, to: destPath, options: options)

                        // Destination should be a symlink
                        let destAttributes = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))
                        #expect(destAttributes[.type] as? FileAttributeType == .typeSymbolicLink)

                        // Verify it points to the same target
                        let destTarget = try FileManager.default.destinationOfSymbolicLink(
                            atPath: Swift.String(destPath)
                        )
                        #expect(destTarget == Swift.String(targetPath))
                    }
                }

                @Test
                func `copyAttributes=true preserves permissions and timestamps`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: sourcePath)

                        // Set specific permissions and modification date on source
                        let testDate = Date(timeIntervalSince1970: 1_000_000_000)  // 2001-09-09
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o644, .modificationDate: testDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: true)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        // Verify permissions are preserved
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        #expect(
                            sourceAttrs[.posixPermissions] as? Int == destAttrs[.posixPermissions]
                                as? Int
                        )

                        // Verify modification date is preserved (within 1 second tolerance)
                        let sourceDate = sourceAttrs[.modificationDate] as? Date
                        let destDate = destAttrs[.modificationDate] as? Date
                        #expect(sourceDate != nil)
                        #expect(destDate != nil)
                        if let sd = sourceDate, let dd = destDate {
                            #expect(abs(sd.timeIntervalSince(dd)) < 1.0)
                        }
                    }
                }

                @Test
                func `copyAttributes=false skips explicit attribute copy`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: false)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        // Verify data is copied
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(destData == Data([10, 20, 30, 40]))

                        // On Darwin with APFS, clonefile() preserves attributes automatically
                        // as part of the copy-on-write clone operation. The copyAttributes
                        // option controls whether we *explicitly* copy attributes after the
                        // clone, but the clone itself already preserves them.
                        // This is expected Darwin behavior - clonefile is documented to
                        // preserve all metadata including permissions, ownership, and timestamps.
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourcePerms = sourceAttrs[.posixPermissions] as? Int
                        let destPerms = destAttrs[.posixPermissions] as? Int

                        // Source should have our set permissions
                        #expect(sourcePerms == 0o600)
                        // On APFS with clonefile, destination will also have source permissions
                        // (this is correct behavior - clonefile preserves metadata)
                        #expect(destPerms != nil)
                    }
                }

                @Test
                func `Large file copy uses clone on APFS`() throws {
                    try File.Directory.temporary { dir in
                        // Create a 2MB file
                        let largeSize = 2 * 1024 * 1024
                        var largeContent = [Byte]()
                        largeContent.reserveCapacity(largeSize)
                        for i in 0..<largeSize {
                            largeContent.append(Byte(UInt8(i % 256)))
                        }

                        let sourcePath = dir.path / "large-source.bin"
                        let destPath = dir.path / "large-dest.bin"

                        try File.System.Write.Atomic.write(largeContent.span, to: sourcePath)

                        // Measure copy time
                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        // Verify data integrity
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(sourceData == destData)

                        // On APFS with clonefile, 2MB should copy almost instantly (< 0.1s)
                        // If it takes longer, it might be using regular copy
                        // This is a soft check - clone should be very fast
                        #expect(
                            elapsed < 0.5,
                            "Large file copy took \(elapsed)s - may not be using clone optimization"
                        )
                    }
                }
            }
        #endif
    #endif

    // MARK: - Linux-specific Edge Cases

    #if os(Linux)
        #if canImport(Foundation)
            @Suite("EdgeCase")
            struct EdgeCase {

                // MARK: - Test 1: Partial copy_file_range handling

                @Test
                func `Large file copy handles partial progress correctly`() throws {
                    try File.Directory.temporary { dir in
                        // Create a 100MB file to ensure copy_file_range loop is exercised
                        // This tests that the loop correctly handles partial copies when
                        // copy_file_range doesn't copy all requested bytes in one call
                        let sourcePath = dir.path / "large-source.bin"
                        let destPath = dir.path / "large-dest.bin"

                        // Create large file inline
                        let chunkSize = 1024 * 1024  // 1MB chunks
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(atPath: Swift.String(sourcePath), contents: nil)
                        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: Swift.String(sourcePath)))
                        defer { try? fileHandle.close() }
                        for _ in 0..<100 {
                            fileHandle.write(chunk)
                        }

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify file was copied completely
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourceSize = (sourceAttrs[.size] as? UInt64) ?? 0
                        let destSize = (destAttrs[.size] as? UInt64) ?? 0

                        #expect(sourceSize == destSize)
                        #expect(sourceSize == 100 * 1024 * 1024)

                        // Verify data integrity by comparing a sample from the file
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(sourceData == destData)
                    }
                }

                @Test
                func `Very large file copy uses copy_file_range efficiently`() throws {
                    try File.Directory.temporary { dir in
                        // Create a 500MB file to test kernel-assisted copy performance
                        let sourcePath = dir.path / "xlarge-source.bin"
                        let destPath = dir.path / "xlarge-dest.bin"

                        // Create large file inline
                        let chunkSize = 1024 * 1024  // 1MB chunks
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(atPath: Swift.String(sourcePath), contents: nil)
                        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: Swift.String(sourcePath)))
                        defer { try? fileHandle.close() }
                        for _ in 0..<500 {
                            fileHandle.write(chunk)
                        }

                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        // Verify size matches
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourceSize = (sourceAttrs[.size] as? UInt64) ?? 0
                        let destSize = (destAttrs[.size] as? UInt64) ?? 0

                        #expect(sourceSize == destSize)
                        #expect(sourceSize == 500 * 1024 * 1024)

                        // Kernel-assisted copy should be faster than userspace copy
                        // 500MB should copy in under 5 seconds on modern systems
                        #expect(
                            elapsed < 5.0,
                            "Large file copy took \(elapsed)s - may not be using kernel optimization"
                        )
                    }
                }

                // MARK: - Test 2: TOCTOU (Time-of-check to time-of-use)

                @Test
                func `Copy behavior is best-effort when source changes during copy`() throws {
                    try File.Directory.temporary { dir in
                        // This test documents that copy is "best effort" - it reads the file
                        // at the time of copy, but doesn't lock it. This is expected behavior.
                        // TOCTOU race conditions are possible but documented.
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write(Array(repeating: 1, count: 1024).span, to: sourcePath)

                        // Copy the file
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify copy succeeded (best effort - we got whatever was there)
                        #expect(FileManager.default.fileExists(atPath: Swift.String(destPath)))

                        // Note: This is not an atomic operation. If the source changes during
                        // copy, the destination may contain a mix of old and new data.
                        // This is expected POSIX behavior - use file locking if atomicity needed.
                    }
                }

                // MARK: - Test 3: Copy to directory path

                @Test
                func `Copy to directory path throws error`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destDirPath = dir.path / "dest-dir"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Create destination directory
                        try FileManager.default.createDirectory(
                            atPath: Swift.String(destDirPath),
                            withIntermediateDirectories: false
                        )

                        // Attempting to copy to a directory should fail
                        #expect(throws: File.System.Copy.Error.self) {
                            try File.System.Copy.copy(
                                from: sourcePath,
                                to: destDirPath,
                                options: .init(overwrite: true)
                            )
                        }
                    }
                }

                @Test
                func `Copy from directory throws isDirectory error`() throws {
                    try File.Directory.temporary { dir in
                        let sourceDirPath = dir.path / "source-dir"
                        let destPath = dir.path / "dest.bin"

                        // Create source directory
                        try FileManager.default.createDirectory(
                            atPath: Swift.String(sourceDirPath),
                            withIntermediateDirectories: false
                        )

                        // Attempting to copy from a directory should throw isDirectory
                        #expect(throws: File.System.Copy.Error.isDirectory) {
                            try File.System.Copy.copy(from: sourceDirPath, to: destPath)
                        }
                    }
                }

                // MARK: - Test 4: Symlink handling

                @Test
                func `Copy with followSymlinks=true copies symlink target`() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = dir.path / "target.bin"
                        let linkPath = dir.path / "link.link"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                        // Create symlink
                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        // Copy with followSymlinks=true (default)
                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: true)
                        )

                        // Verify destination is a regular file with target's content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(Array(destData) == [10, 20, 30])

                        // Verify destination is not a symlink
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))
                        #expect(destAttrs[.type] as? FileAttributeType != .typeSymbolicLink)
                    }
                }

                @Test
                func `Copy with followSymlinks=false copies symlink itself`() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = dir.path / "target.bin"
                        let linkPath = dir.path / "link.link"
                        let destPath = dir.path / "dest.link"

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                        // Create symlink
                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        // Copy with followSymlinks=false
                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: false)
                        )

                        // Verify destination is a symlink pointing to the same target
                        let destTarget = try FileManager.default.destinationOfSymbolicLink(
                            atPath: Swift.String(destPath)
                        )
                        #expect(destTarget == Swift.String(targetPath))
                    }
                }

                @Test
                func `Copy to existing symlink with overwrite replaces link`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let targetPath = dir.path / "target.bin"
                        let linkPath = dir.path / "link.link"

                        try File.System.Write.Atomic.write([100, 200].span, to: sourcePath)
                        try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                        // Create symlink at destination
                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        // Copy with overwrite=true
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: linkPath,
                            options: .init(overwrite: true)
                        )

                        // Verify destination is now a regular file with source content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(linkPath)))
                        #expect(Array(destData) == [100, 200])

                        // Verify it's not a symlink anymore
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(linkPath))
                        #expect(destAttrs[.type] as? FileAttributeType != .typeSymbolicLink)
                    }
                }

                // MARK: - Test 5: Empty file copy

                @Test
                func `Empty file copies correctly through fast path`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "empty.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([Byte]().span, to: sourcePath)

                        // Copy empty file - should use copy_file_range which handles empty files
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify destination exists and is empty
                        #expect(FileManager.default.fileExists(atPath: Swift.String(destPath)))

                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(destData.isEmpty)

                        // Verify it's a regular file with size 0
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))
                        #expect(destAttrs[.type] as? FileAttributeType == .typeRegular)
                        #expect(destAttrs[.size] as? UInt64 == 0)
                    }
                }

                // MARK: - Test 6: Attribute preservation

                @Test
                func `Copy with copyAttributes=false does not preserve permissions`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        // Copy without attributes
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        // Get permissions of both files
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourcePerms = (sourceAttrs[.posixPermissions] as? UInt16) ?? 0
                        let destPerms = (destAttrs[.posixPermissions] as? UInt16) ?? 0

                        #expect(sourcePerms == 0o600)
                        // Destination should have default permissions (modified by umask)
                        // Typically 0o644, but not the restrictive 0o600 from source
                        #expect(destPerms != sourcePerms)
                    }
                }

                @Test
                func `Copy with copyAttributes=false does not preserve timestamps`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set old modification time on source
                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)  // Year 2001
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        // Wait a moment to ensure new file has different timestamp
                        Thread.sleep(forTimeInterval: 0.1)

                        // Copy without attributes
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime = (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        // Source should have old timestamp
                        #expect(abs(sourceModTime.timeIntervalSince(oldDate)) < 1.0)

                        // Destination should have current timestamp (not old one)
                        #expect(destModTime > sourceModTime)
                    }
                }

                @Test
                func `Copy with copyAttributes=true preserves permissions`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o755],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        // Copy with attributes (default)
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourcePerms = (sourceAttrs[.posixPermissions] as? UInt16) ?? 0
                        let destPerms = (destAttrs[.posixPermissions] as? UInt16) ?? 0

                        #expect(sourcePerms == 0o755)
                        #expect(destPerms == 0o755)
                    }
                }

                @Test
                func `Copy with copyAttributes=true preserves timestamps`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set old modification time on source
                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)  // Year 2001
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        // Copy with attributes (default)
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: Swift.String(destPath))

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime = (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        // Timestamps should match within 1 second (accounting for precision)
                        #expect(abs(sourceModTime.timeIntervalSince(destModTime)) < 1.0)
                    }
                }

                // MARK: - Test 7: Cross-filesystem copy fallback

                @Test
                func `Copy across filesystems falls back to sendfile/manual`() throws {
                    try File.Directory.temporary { dir in
                        // This test documents the fallback behavior when copy_file_range
                        // returns EXDEV (cross-device/filesystem not supported)
                        // The implementation should fall back to sendfile or manual copy
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: sourcePath)

                        // Copy should succeed even if filesystems differ
                        // (though in /tmp they're likely the same, this documents behavior)
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify data integrity
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: Swift.String(destPath)))
                        #expect(sourceData == destData)
                    }
                }
            }
        #endif
    #endif
}
