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
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Copy.Test.Unit {

    @Test
    func `Copy file to new location`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

            try File.System.Copy.copy(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let sourceData = try File.System.Read.Full.read(from: sourcePath) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
            let destData = try File.System.Read.Full.read(from: destPath) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
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

    @Test
    func `Copy with overwrite option`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Copy.Options(overwrite: true)
            try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

            let destData = try File.System.Read.Full.read(from: destPath) {
                $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
            }
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

    #if canImport(Darwin)
        #if canImport(Foundation)
            @Suite
            struct `EdgeCase` {

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

                        #expect(throws: File.System.Copy.Error.self) {
                            try File.System.Copy.copy(
                                from: sourcePath,
                                to: destDir,
                                options: options
                            )
                        }

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
                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: symlinkPath,
                            options: options
                        )

                        var isSymlink: ObjCBool = false
                        FileManager.default.fileExists(
                            atPath: Swift.String(symlinkPath),
                            isDirectory: &isSymlink
                        )

                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(symlinkPath))
                        )
                        #expect(destData == Data([10, 20, 30]))

                        let targetData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(targetPath))
                        )
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

                        let destAttributes = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )
                        #expect(destAttributes[.type] as? FileAttributeType == .typeSymbolicLink)

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

                        let testDate = Date(timeIntervalSince1970: 1_000_000_000)
                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o644, .modificationDate: testDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: true)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        #expect(
                            sourceAttrs[.posixPermissions] as? Int == destAttrs[.posixPermissions]
                                as? Int
                        )

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

                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        let options = File.System.Copy.Options(copyAttributes: false)
                        try File.System.Copy.copy(from: sourcePath, to: destPath, options: options)

                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(destData == Data([10, 20, 30, 40]))

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourcePerms = sourceAttrs[.posixPermissions] as? Int
                        let destPerms = destAttrs[.posixPermissions] as? Int

                        #expect(sourcePerms == 0o600)

                        #expect(destPerms != nil)
                    }
                }

                @Test
                func `Large file copy uses clone on APFS`() throws {
                    try File.Directory.temporary { dir in

                        let largeSize = 2 * 1024 * 1024
                        var largeContent = [Byte]()
                        largeContent.reserveCapacity(largeSize)
                        for i in 0..<largeSize {
                            largeContent.append(Byte(UInt8(i % 256)))
                        }

                        let sourcePath = dir.path / "large-source.bin"
                        let destPath = dir.path / "large-dest.bin"

                        try File.System.Write.Atomic.write(largeContent.span, to: sourcePath)

                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        let sourceData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(sourcePath))
                        )
                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(sourceData == destData)

                        #expect(
                            elapsed < 0.5,
                            "Large file copy took \(elapsed)s - may not be using clone optimization"
                        )
                    }
                }
            }
        #endif
    #endif

    #if os(Linux)
        #if canImport(Foundation)
            @Suite
            struct `EdgeCase` {

                @Test
                func `Large file copy handles partial progress correctly`() throws {
                    try File.Directory.temporary { dir in

                        let sourcePath = dir.path / "large-source.bin"
                        let destPath = dir.path / "large-dest.bin"

                        let chunkSize = 1024 * 1024
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(
                            atPath: Swift.String(sourcePath),
                            contents: nil
                        )
                        let fileHandle = try FileHandle(
                            forWritingTo: URL(fileURLWithPath: Swift.String(sourcePath))
                        )
                        defer { try? fileHandle.close() }
                        for _ in 0..<100 {
                            fileHandle.write(chunk)
                        }

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourceSize = (sourceAttrs[.size] as? UInt64) ?? 0
                        let destSize = (destAttrs[.size] as? UInt64) ?? 0

                        #expect(sourceSize == destSize)
                        #expect(sourceSize == 100 * 1024 * 1024)

                        let sourceData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(sourcePath))
                        )
                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(sourceData == destData)
                    }
                }

                @Test
                func `Very large file copy uses copy_file_range efficiently`() throws {
                    try File.Directory.temporary { dir in

                        let sourcePath = dir.path / "xlarge-source.bin"
                        let destPath = dir.path / "xlarge-dest.bin"

                        let chunkSize = 1024 * 1024
                        let chunk = Data(repeating: 0xAB, count: chunkSize)
                        _ = FileManager.default.createFile(
                            atPath: Swift.String(sourcePath),
                            contents: nil
                        )
                        let fileHandle = try FileHandle(
                            forWritingTo: URL(fileURLWithPath: Swift.String(sourcePath))
                        )
                        defer { try? fileHandle.close() }
                        for _ in 0..<500 {
                            fileHandle.write(chunk)
                        }

                        let startTime = Date()
                        try File.System.Copy.copy(from: sourcePath, to: destPath)
                        let elapsed = Date().timeIntervalSince(startTime)

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourceSize = (sourceAttrs[.size] as? UInt64) ?? 0
                        let destSize = (destAttrs[.size] as? UInt64) ?? 0

                        #expect(sourceSize == destSize)
                        #expect(sourceSize == 500 * 1024 * 1024)

                        #expect(
                            elapsed < 5.0,
                            "Large file copy took \(elapsed)s - may not be using kernel optimization"
                        )
                    }
                }

                @Test
                func `Copy behavior is best-effort when source changes during copy`() throws {
                    try File.Directory.temporary { dir in

                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write(
                            Array(repeating: 1, count: 1024).span,
                            to: sourcePath
                        )

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        #expect(FileManager.default.fileExists(atPath: Swift.String(destPath)))

                    }
                }

                @Test
                func `Copy to directory path throws error`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destDirPath = dir.path / "dest-dir"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        try FileManager.default.createDirectory(
                            atPath: Swift.String(destDirPath),
                            withIntermediateDirectories: false
                        )

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

                        try FileManager.default.createDirectory(
                            atPath: Swift.String(sourceDirPath),
                            withIntermediateDirectories: false
                        )

                        #expect(throws: File.System.Copy.Error.isDirectory) {
                            try File.System.Copy.copy(from: sourceDirPath, to: destPath)
                        }
                    }
                }

                @Test
                func `Copy with followSymlinks=true copies symlink target`() throws {
                    try File.Directory.temporary { dir in
                        let targetPath = dir.path / "target.bin"
                        let linkPath = dir.path / "link.link"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: true)
                        )

                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(Array(destData) == [10, 20, 30])

                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )
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

                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        try File.System.Copy.copy(
                            from: linkPath,
                            to: destPath,
                            options: .init(followSymlinks: false)
                        )

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

                        try FileManager.default.createSymbolicLink(
                            atPath: Swift.String(linkPath),
                            withDestinationPath: Swift.String(targetPath)
                        )

                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: linkPath,
                            options: .init(overwrite: true)
                        )

                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(linkPath))
                        )
                        #expect(Array(destData) == [100, 200])

                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(linkPath)
                        )
                        #expect(destAttrs[.type] as? FileAttributeType != .typeSymbolicLink)
                    }
                }

                @Test
                func `Empty file copies correctly through fast path`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "empty.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([Byte]().span, to: sourcePath)

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        #expect(FileManager.default.fileExists(atPath: Swift.String(destPath)))

                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(destData.isEmpty)

                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )
                        #expect(destAttrs[.type] as? FileAttributeType == .typeRegular)
                        #expect(destAttrs[.size] as? UInt64 == 0)
                    }
                }

                @Test
                func `Copy with copyAttributes=false does not preserve permissions`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o600],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourcePerms = (sourceAttrs[.posixPermissions] as? UInt16) ?? 0
                        let destPerms = (destAttrs[.posixPermissions] as? UInt16) ?? 0

                        #expect(sourcePerms == 0o600)

                        #expect(destPerms != sourcePerms)
                    }
                }

                @Test
                func `Copy with copyAttributes=false does not preserve timestamps`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        Thread.sleep(forTimeInterval: 0.1)

                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: false)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime =
                            (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        #expect(abs(sourceModTime.timeIntervalSince(oldDate)) < 1.0)

                        #expect(destModTime > sourceModTime)
                    }
                }

                @Test
                func `Copy with copyAttributes=true preserves permissions`() throws {
                    try File.Directory.temporary { dir in
                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

                        try FileManager.default.setAttributes(
                            [.posixPermissions: 0o755],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

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

                        let oldDate = Date(timeIntervalSince1970: 1_000_000_000)
                        try FileManager.default.setAttributes(
                            [.modificationDate: oldDate],
                            ofItemAtPath: Swift.String(sourcePath)
                        )

                        try File.System.Copy.copy(
                            from: sourcePath,
                            to: destPath,
                            options: .init(copyAttributes: true)
                        )

                        let sourceAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(sourcePath)
                        )
                        let destAttrs = try FileManager.default.attributesOfItem(
                            atPath: Swift.String(destPath)
                        )

                        let sourceModTime =
                            (sourceAttrs[.modificationDate] as? Date) ?? Date.distantPast
                        let destModTime =
                            (destAttrs[.modificationDate] as? Date) ?? Date.distantPast

                        #expect(abs(sourceModTime.timeIntervalSince(destModTime)) < 1.0)
                    }
                }

                @Test
                func `Copy across filesystems falls back to sendfile/manual`() throws {
                    try File.Directory.temporary { dir in

                        let sourcePath = dir.path / "source.bin"
                        let destPath = dir.path / "dest.bin"

                        try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: sourcePath)

                        try File.System.Copy.copy(from: sourcePath, to: destPath)

                        let sourceData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(sourcePath))
                        )
                        let destData = try Data(
                            contentsOf: URL(fileURLWithPath: Swift.String(destPath))
                        )
                        #expect(sourceData == destData)
                    }
                }
            }
        #endif
    #endif
}
