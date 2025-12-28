//
//  File.System.Copy Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if canImport(Foundation)
    import Foundation
#endif

extension File.System.Copy {
    #TestSuites
}

extension File.System.Copy.Test.Unit {
    // MARK: - Basic Copy

    @Test("Copy file to new location")
    func copyFileToNewLocation() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let sourceData = try File.System.Read.Full.read(from: sourcePath)
            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(sourceData == destData)
        }
    }

    @Test("Copy preserves source file")
    func copyPreservesSourceFile() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            // Source should still exist
            #expect(File.System.Stat.exists(at: sourcePath))
        }
    }

    @Test("Copy empty file")
    func copyEmptyFile() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "empty.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([UInt8]().span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(destData.isEmpty)
        }
    }

    // MARK: - Options

    @Test("Copy with overwrite option")
    func copyWithOverwriteOption() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Copy.Options(overwrite: true)
            try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(destData == [1, 2, 3])
        }
    }

    @Test("Copy without overwrite throws when destination exists")
    func copyWithoutOverwriteThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Copy.Options(overwrite: false)
            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)
            }
        }
    }

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.System.Copy.Options()
        #expect(options.overwrite == false)
        #expect(options.copyAttributes == true)
        #expect(options.followSymlinks == true)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
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

    @Test("Copy non-existent source throws sourceNotFound")
    func copyNonExistentSourceThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "non-existent.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            #expect(throws: File.System.Copy.Error.self) {
                try File.System.Copy.copy(from: sourcePath, to: destPath)
            }
        }
    }

    @Test("Copy to existing file without overwrite throws destinationExists")
    func copyToExistingFileThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99].span, to: destPath)

            #expect(throws: File.System.Copy.Error.destinationExists(destPath)) {
                try File.System.Copy.copy(from: sourcePath, to: destPath)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("sourceNotFound error description")
    func sourceNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.System.Copy.Error.sourceNotFound(path)
        #expect(error.description.contains("Source not found"))
    }

    @Test("destinationExists error description")
    func destinationExistsErrorDescription() throws {
        let path = File.Path("/tmp/existing")
        let error = File.System.Copy.Error.destinationExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
        let error = File.System.Copy.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() throws {
        let path = File.Path("/tmp")
        let error = File.System.Copy.Error.isDirectory(path)
        #expect(error.description.contains("Is a directory"))
    }

    @Test("copyFailed error description")
    func copyFailedErrorDescription() {
        let error = File.System.Copy.Error.copyFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Copy failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = File.Path("/tmp/a")
        let path2 = File.Path("/tmp/a")

        #expect(
            File.System.Copy.Error.sourceNotFound(path1)
                == File.System.Copy.Error.sourceNotFound(path2)
        )
        #expect(
            File.System.Copy.Error.destinationExists(path1)
                == File.System.Copy.Error.destinationExists(path2)
        )
    }

    // MARK: - Darwin-specific Edge Cases

    #if canImport(Darwin)
        #if canImport(Foundation)
            @Suite("EdgeCase")
            struct EdgeCase {

                @Test("Overwrite when destination is directory fails appropriately")
                func overwriteDestinationDirectoryFails() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destDir = File.Path(dir.path, appending: "dest-dir")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
                        try FileManager.default.createDirectory(
                            atPath: String(destDir),
                            withIntermediateDirectories: false
                        )

                        let options = File.System.Copy.Options(overwrite: true)

                        // COPYFILE_UNLINK should not delete directories
                        #expect(throws: File.System.Copy.Error.self) {
                            try File.System.Copy.copy(from: sourcePath, to: destDir, options: options)
                        }

                        // Verify directory still exists
                        #expect(FileManager.default.fileExists(atPath: String(destDir)))
                    }
                }

                @Test("Overwrite when destination is symlink removes symlink")
                func overwriteDestinationSymlink() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let targetPath = File.Path(dir.path, appending: "target.bin")
                        let symlinkPath = File.Path(dir.path, appending: "symlink.link")

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: sourcePath)
                        try File.System.Write.Atomic.write([99].span, to: targetPath)

                        try FileManager.default.createSymbolicLink(
                            atPath: String(symlinkPath),
                            withDestinationPath: String(targetPath)
                        )

                        let options = File.System.Copy.Options(overwrite: true)
                        try File.System.Copy.copy(from: sourcePath, to: symlinkPath, options: options)

                        // Destination should now be a regular file, not a symlink
                        var isSymlink: ObjCBool = false
                        FileManager.default.fileExists(atPath: String(symlinkPath), isDirectory: &isSymlink)

                        // Verify it's now a regular file with source content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(symlinkPath)))
                        #expect(destData == Data([10, 20, 30]))

                        // Verify original target file is unchanged
                        let targetData = try Data(contentsOf: URL(fileURLWithPath: String(targetPath)))
                        #expect(targetData == Data([99]))
                    }
                }

                @Test("COPYFILE_NOFOLLOW with symlink source copies symlink itself")
                func copySymlinkWithoutFollowing() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = File.Path(dir.path, appending: "target.bin")
                        let symlinkPath = File.Path(dir.path, appending: "source-symlink.link")
                        let destPath = File.Path(dir.path, appending: "dest-symlink.link")

                        try File.System.Write.Atomic.write([99, 88, 77].span, to: targetPath)

                        try FileManager.default.createSymbolicLink(
                            atPath: String(symlinkPath),
                            withDestinationPath: String(targetPath)
                        )

                        let options = File.System.Copy.Options(followSymlinks: false)
                        try File.System.Copy.copy(from: symlinkPath, to: destPath, options: options)

                        // Destination should be a symlink
                        let destAttributes = try FileManager.default.attributesOfItem(atPath: String(destPath))
                        #expect(destAttributes[.type] as? FileAttributeType == .typeSymbolicLink)

                        // Verify it points to the same target
                        let destTarget = try FileManager.default.destinationOfSymbolicLink(
                            atPath: String(destPath)
                        )
                        #expect(destTarget == String(targetPath))
                    }
                }

                @Test("copyAttributes=true preserves permissions and timestamps")
                func copyAttributesPreservesMetadata() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: sourcePath)

                        // Set specific permissions and modification date on source
                        let testDate = Date(timeIntervalSince1970: 1_000_000_000)  // 2001-09-09
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o644, .modificationDate: testDate],
                            ofItemAtPath: String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: true)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        // Verify permissions are preserved
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

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

                @Test("copyAttributes=false copies only data")
                func copyAttributesFalseSkipsMetadata() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: false)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        // Verify data is copied
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
                        #expect(destData == Data([10, 20, 30, 40]))

                        // Verify permissions are default (not copied from source)
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourcePerms = sourceAttrs[.posixPermissions] as? Int
                        let destPerms = destAttrs[.posixPermissions] as? Int

                        // Destination should have default permissions, not source's 0o600
                        #expect(sourcePerms == 0o600)
                        #expect(destPerms != 0o600)
                    }
                }

                @Test("Large file copy uses clone on APFS")
                func largeFileCopyUsesClone() throws {
                    try File.Directory.temporary { dir in
                        // Create a 2MB file
                        let largeSize = 2 * 1024 * 1024
                        var largeContent = [UInt8]()
                        largeContent.reserveCapacity(largeSize)
                        for i in 0..<largeSize {
                            largeContent.append(UInt8(i % 256))
                        }

                        let sourcePath = File.Path(dir.path, appending: "large-source.bin")
                        let destPath = File.Path(dir.path, appending: "large-dest.bin")

                        try File.System.Write.Atomic.write(largeContent.span, to: sourcePath)

                        // Measure copy time
                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        // Verify data integrity
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
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

                @Test("Large file copy handles partial progress correctly")
                func largeFileCopyHandlesPartialProgress() throws {
                    try File.Directory.temporary { dir in
                        // Create a 100MB file to ensure copy_file_range loop is exercised
                        // This tests that the loop correctly handles partial copies when
                        // copy_file_range doesn't copy all requested bytes in one call
                        let sourcePath = File.Path(dir.path, appending: "large-source.bin")
                        let destPath = File.Path(dir.path, appending: "large-dest.bin")

                        // Create large file inline
                        let chunkSize = 1024 * 1024  // 1MB chunks
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(atPath: String(sourcePath), contents: nil)
                        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: String(sourcePath)))
                        defer { try? fileHandle.close() }
                        for _ in 0..<100 {
                            fileHandle.write(chunk)
                        }

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify file was copied completely
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourceSize = (sourceAttrs[.size] as? UInt64) ?? 0
                        let destSize = (destAttrs[.size] as? UInt64) ?? 0

                        #expect(sourceSize == destSize)
                        #expect(sourceSize == 100 * 1024 * 1024)

                        // Verify data integrity by comparing a sample from the file
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
                        #expect(sourceData == destData)
                    }
                }

                @Test("Very large file copy uses copy_file_range efficiently")
                func veryLargeFileCopyUsesKernelPath() throws {
                    try File.Directory.temporary { dir in
                        // Create a 500MB file to test kernel-assisted copy performance
                        let sourcePath = File.Path(dir.path, appending: "xlarge-source.bin")
                        let destPath = File.Path(dir.path, appending: "xlarge-dest.bin")

                        // Create large file inline
                        let chunkSize = 1024 * 1024  // 1MB chunks
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(atPath: String(sourcePath), contents: nil)
                        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: String(sourcePath)))
                        defer { try? fileHandle.close() }
                        for _ in 0..<500 {
                            fileHandle.write(chunk)
                        }

                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        // Verify size matches
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

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

                @Test("Copy behavior is best-effort when source changes during copy")
                func copyBestEffortWhenSourceChanges() throws {
                    try File.Directory.temporary { dir in
                        // This test documents that copy is "best effort" - it reads the file
                        // at the time of copy, but doesn't lock it. This is expected behavior.
                        // TOCTOU race conditions are possible but documented.
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write(Array(repeating: 1, count: 1024).span, to: sourcePath)

                        // Copy the file
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify copy succeeded (best effort - we got whatever was there)
                        #expect(FileManager.default.fileExists(atPath: String(destPath)))

                        // Note: This is not an atomic operation. If the source changes during
                        // copy, the destination may contain a mix of old and new data.
                        // This is expected POSIX behavior - use file locking if atomicity needed.
                    }
                }

                // MARK: - Test 3: Copy to directory path

                @Test("Copy to directory path throws error")
                func copyToDirectoryPathThrows() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destDirPath = File.Path(dir.path, appending: "dest-dir")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Create destination directory
                        try FileManager.default.createDirectory(
                            atPath: String(destDirPath),
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

                @Test("Copy from directory throws isDirectory error")
                func copyFromDirectoryThrows() throws {
                    try File.Directory.temporary { dir in
                        let sourceDirPath = File.Path(dir.path, appending: "source-dir")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        // Create source directory
                        try FileManager.default.createDirectory(
                            atPath: String(sourceDirPath),
                            withIntermediateDirectories: false
                        )

                        // Attempting to copy from a directory should throw isDirectory
                        #expect(throws: File.System.Copy.Error.isDirectory(sourceDirPath)) {
                            try File.System.Copy.copy(from: sourceDirPath, to: destPath)
                        }
                    }
                }

                // MARK: - Test 4: Symlink handling

                @Test("Copy with followSymlinks=true copies symlink target")
                func copyFollowsSymlinkWhenRequested() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = File.Path(dir.path, appending: "target.bin")
                        let linkPath = File.Path(dir.path, appending: "link.link")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                        // Create symlink
                        try FileManager.default.createSymbolicLink(
                            atPath: String(linkPath),
                            withDestinationPath: String(targetPath)
                        )

                        // Copy with followSymlinks=true (default)
                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: true)
                        )

                        // Verify destination is a regular file with target's content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
                        #expect(Array(destData) == [10, 20, 30])

                        // Verify destination is not a symlink
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))
                        #expect(destAttrs[.type] as? FileAttributeType != .typeSymbolicLink)
                    }
                }

                @Test("Copy with followSymlinks=false copies symlink itself")
                func copySymlinkWithoutFollowing() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = File.Path(dir.path, appending: "target.bin")
                        let linkPath = File.Path(dir.path, appending: "link.link")
                        let destPath = File.Path(dir.path, appending: "dest.link")

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                        // Create symlink
                        try FileManager.default.createSymbolicLink(
                            atPath: String(linkPath),
                            withDestinationPath: String(targetPath)
                        )

                        // Copy with followSymlinks=false
                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: false)
                        )

                        // Verify destination is a symlink pointing to the same target
                        let destTarget = try FileManager.default.destinationOfSymbolicLink(
                            atPath: String(destPath)
                        )
                        #expect(destTarget == String(targetPath))
                    }
                }

                @Test("Copy to existing symlink with overwrite replaces link")
                func copyToExistingSymlinkReplaces() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let targetPath = File.Path(dir.path, appending: "target.bin")
                        let linkPath = File.Path(dir.path, appending: "link.link")

                        try File.System.Write.Atomic.write([100, 200].span, to: sourcePath)
                        try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                        // Create symlink at destination
                        try FileManager.default.createSymbolicLink(
                            atPath: String(linkPath),
                            withDestinationPath: String(targetPath)
                        )

                        // Copy with overwrite=true
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: linkPath,
                            options: .init(overwrite: true)
                        )

                        // Verify destination is now a regular file with source content
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(linkPath)))
                        #expect(Array(destData) == [100, 200])

                        // Verify it's not a symlink anymore
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(linkPath))
                        #expect(destAttrs[.type] as? FileAttributeType != .typeSymbolicLink)
                    }
                }

                // MARK: - Test 5: Empty file copy

                @Test("Empty file copies correctly through fast path")
                func emptyFileCopiesThroughFastPath() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "empty.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([UInt8]().span, to: sourcePath)

                        // Copy empty file - should use copy_file_range which handles empty files
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify destination exists and is empty
                        #expect(FileManager.default.fileExists(atPath: String(destPath)))

                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
                        #expect(destData.isEmpty)

                        // Verify it's a regular file with size 0
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))
                        #expect(destAttrs[.type] as? FileAttributeType == .typeRegular)
                        #expect(destAttrs[.size] as? UInt64 == 0)
                    }
                }

                // MARK: - Test 6: Attribute preservation

                @Test("Copy with copyAttributes=false does not preserve permissions")
                func copyWithoutAttributesNoPermissions() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: String(sourcePath)
                        )

                        // Copy without attributes
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        // Get permissions of both files
                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourcePerms = (sourceAttrs[.posixPermissions] as? UInt16) ?? 0
                        let destPerms = (destAttrs[.posixPermissions] as? UInt16) ?? 0

                        #expect(sourcePerms == 0o600)
                        // Destination should have default permissions (modified by umask)
                        // Typically 0o644, but not the restrictive 0o600 from source
                        #expect(destPerms != sourcePerms)
                    }
                }

                @Test("Copy with copyAttributes=false does not preserve timestamps")
                func copyWithoutAttributesNoTimestamps() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set old modification time on source
                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)  // Year 2001
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: String(sourcePath)
                        )

                        // Wait a moment to ensure new file has different timestamp
                        Thread.sleep(forTimeInterval: 0.1)

                        // Copy without attributes
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime = (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        // Source should have old timestamp
                        #expect(abs(sourceModTime.timeIntervalSince(oldDate)) < 1.0)

                        // Destination should have current timestamp (not old one)
                        #expect(destModTime > sourceModTime)
                    }
                }

                @Test("Copy with copyAttributes=true preserves permissions")
                func copyWithAttributesPreservesPermissions() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set specific permissions on source
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o755],
                            ofItemAtPath: String(sourcePath)
                        )

                        // Copy with attributes (default)
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourcePerms = (sourceAttrs[.posixPermissions] as? UInt16) ?? 0
                        let destPerms = (destAttrs[.posixPermissions] as? UInt16) ?? 0

                        #expect(sourcePerms == 0o755)
                        #expect(destPerms == 0o755)
                    }
                }

                @Test("Copy with copyAttributes=true preserves timestamps")
                func copyWithAttributesPreservesTimestamps() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        // Set old modification time on source
                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)  // Year 2001
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: String(sourcePath)
                        )

                        // Copy with attributes (default)
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(atPath: String(sourcePath))
                        let destAttrs = try FileManager.default.attributesOfItem(atPath: String(destPath))

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime = (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        // Timestamps should match within 1 second (accounting for precision)
                        #expect(abs(sourceModTime.timeIntervalSince(destModTime)) < 1.0)
                    }
                }

                // MARK: - Test 7: Cross-filesystem copy fallback

                @Test("Copy across filesystems falls back to sendfile/manual")
                func copyAcrossFilesystemsFallsBack() throws {
                    try File.Directory.temporary { dir in
                        // This test documents the fallback behavior when copy_file_range
                        // returns EXDEV (cross-device/filesystem not supported)
                        // The implementation should fall back to sendfile or manual copy
                        let sourcePath = File.Path(dir.path, appending: "source.bin")
                        let destPath = File.Path(dir.path, appending: "dest.bin")

                        try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: sourcePath)

                        // Copy should succeed even if filesystems differ
                        // (though in /tmp they're likely the same, this documents behavior)
                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        // Verify data integrity
                        let sourceData = try Data(contentsOf: URL(fileURLWithPath: String(sourcePath)))
                        let destData = try Data(contentsOf: URL(fileURLWithPath: String(destPath)))
                        #expect(sourceData == destData)
                    }
                }
            }
        #endif
    #endif
}

// MARK: - Performance Tests

extension File.System.Copy.Test.Performance {

    @Test("File.System.Copy.copy (1MB)", .timed(iterations: 10, warmup: 2))
    func copyFile1MB() throws {
        let td = try File.Directory.Temporary.system
        let sourcePath = File.Path(
            td.path,
            appending: "perf_copy_src_\(Int.random(in: 0..<Int.max)).bin"
        )
        let destPath = File.Path(
            td.path,
            appending: "perf_copy_dst_\(Int.random(in: 0..<Int.max)).bin"
        )

        // Setup
        let oneMB = [UInt8](repeating: 0xAA, count: 1_000_000)
        try File.System.Write.Atomic.write(oneMB.span, to: sourcePath)

        defer {
            try? File.System.Delete.delete(at: sourcePath)
            try? File.System.Delete.delete(at: destPath)
        }

        try File.System.Copy.copy(from: sourcePath, to: destPath)
    }
}
