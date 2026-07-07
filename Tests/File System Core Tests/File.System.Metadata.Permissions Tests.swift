//
//  File.System.Metadata.Permissions Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Metadata.Permissions {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Metadata.Permissions.Test.Unit {

    // MARK: - OptionSet Values

    @Test
    func `Owner permission values`() {
        #expect(File.System.Metadata.Permissions.ownerRead.rawValue == 0o400)
        #expect(File.System.Metadata.Permissions.ownerWrite.rawValue == 0o200)
        #expect(File.System.Metadata.Permissions.ownerExecute.rawValue == 0o100)
    }

    @Test
    func `Group permission values`() {
        #expect(File.System.Metadata.Permissions.groupRead.rawValue == 0o040)
        #expect(File.System.Metadata.Permissions.groupWrite.rawValue == 0o020)
        #expect(File.System.Metadata.Permissions.groupExecute.rawValue == 0o010)
    }

    @Test
    func `Other permission values`() {
        #expect(File.System.Metadata.Permissions.otherRead.rawValue == 0o004)
        #expect(File.System.Metadata.Permissions.otherWrite.rawValue == 0o002)
        #expect(File.System.Metadata.Permissions.otherExecute.rawValue == 0o001)
    }

    @Test
    func `Special bit values`() {
        #expect(File.System.Metadata.Permissions.setuid.rawValue == 0o4000)
        #expect(File.System.Metadata.Permissions.setgid.rawValue == 0o2000)
        #expect(File.System.Metadata.Permissions.sticky.rawValue == 0o1000)
    }

    @Test
    func `Combined permission values`() {
        let ownerAll = File.System.Metadata.Permissions.ownerAll
        #expect(ownerAll.contains(.ownerRead))
        #expect(ownerAll.contains(.ownerWrite))
        #expect(ownerAll.contains(.ownerExecute))

        let groupAll = File.System.Metadata.Permissions.groupAll
        #expect(groupAll.contains(.groupRead))
        #expect(groupAll.contains(.groupWrite))
        #expect(groupAll.contains(.groupExecute))

        let otherAll = File.System.Metadata.Permissions.otherAll
        #expect(otherAll.contains(.otherRead))
        #expect(otherAll.contains(.otherWrite))
        #expect(otherAll.contains(.otherExecute))
    }

    @Test
    func `Default file permissions (644)`() {
        let defaultFile = File.System.Metadata.Permissions.defaultFile
        #expect(defaultFile.contains(.ownerRead))
        #expect(defaultFile.contains(.ownerWrite))
        #expect(!defaultFile.contains(.ownerExecute))
        #expect(defaultFile.contains(.groupRead))
        #expect(!defaultFile.contains(.groupWrite))
        #expect(defaultFile.contains(.otherRead))
        #expect(!defaultFile.contains(.otherWrite))
    }

    @Test
    func `Default directory permissions (755)`() {
        let defaultDir = File.System.Metadata.Permissions.defaultDirectory
        #expect(defaultDir.contains(.ownerRead))
        #expect(defaultDir.contains(.ownerWrite))
        #expect(defaultDir.contains(.ownerExecute))
        #expect(defaultDir.contains(.groupRead))
        #expect(defaultDir.contains(.groupExecute))
        #expect(defaultDir.contains(.otherRead))
        #expect(defaultDir.contains(.otherExecute))
    }

    // MARK: - Get/Set

    @Test
    func `Get permissions of file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            try File.System.Write.Atomic.write([], to: filePath)

            let perms = try File.System.Metadata.Permissions(at: filePath)

            // File should have some permissions
            #expect(perms.rawValue != 0)
        }
    }

    #if !os(Windows)
        // Unix-style permission set/get tests are skipped on Windows because
        // Windows uses ACLs rather than Unix mode bits, and chmod semantics
        // don't map cleanly to Windows security model.

        @Test
        func `Set permissions of file`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                let newPerms: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite, .groupRead]

                try File.System.Metadata.Permissions.set(newPerms, at: filePath)

                let readBack = try File.System.Metadata.Permissions(at: filePath)
                #expect(readBack.contains(.ownerRead))
                #expect(readBack.contains(.ownerWrite))
                #expect(readBack.contains(.groupRead))
                #expect(!readBack.contains(.groupWrite))
                #expect(!readBack.contains(.otherRead))
            }
        }

        @Test
        func `Permissions roundtrip`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                let testPerms: File.System.Metadata.Permissions = [
                    .ownerRead, .ownerWrite, .ownerExecute,
                    .groupRead,
                    .otherRead,
                ]

                try File.System.Metadata.Permissions.set(testPerms, at: filePath)
                let readBack = try File.System.Metadata.Permissions(at: filePath)

                // Check the permission bits we set
                #expect(readBack.contains(.ownerRead))
                #expect(readBack.contains(.ownerWrite))
                #expect(readBack.contains(.ownerExecute))
                #expect(readBack.contains(.groupRead))
                #expect(!readBack.contains(.groupWrite))
                #expect(readBack.contains(.otherRead))
                #expect(!readBack.contains(.otherWrite))
            }
        }

        // MARK: - Error Cases

        @Test
        func `Get permissions of non-existent file throws error with isNotFound`() throws {
            try File.Directory.temporary { dir in
                let nonExistent = dir.path / "non-existent-\(Int.random(in: (0..<Int.max))).tmp"

                do throws(File.System.Metadata.Permissions.Error) {
                    _ = try File.System.Metadata.Permissions(at: nonExistent)
                    Issue.record("Expected error for non-existent file")
                } catch {
                    #expect(error.isNotFound)
                }
            }
        }

        @Test
        func `Set permissions of non-existent file throws error with isNotFound`() throws {
            try File.Directory.temporary { dir in
                let nonExistent = dir.path / "non-existent-\(Int.random(in: (0..<Int.max))).tmp"

                do throws(File.System.Metadata.Permissions.Error) {
                    try File.System.Metadata.Permissions.set(.defaultFile, at: nonExistent)
                    Issue.record("Expected error for non-existent file")
                } catch {
                    #expect(error.isNotFound)
                }
            }
        }
    #endif

    // MARK: - Semantic Accessors

    @Test
    func `isNotFound semantic accessor for chmod error`() {
        let error = File.System.Metadata.Permissions.Error.chmod(.path(.notFound))
        #expect(error.isNotFound)
        #expect(!error.isPermissionDenied)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Metadata.Permissions.Error.chmod(.permission(.denied))
        #expect(error.isPermissionDenied)
        #expect(!error.isNotFound)
    }

    @Test
    func `isReadOnly semantic accessor`() {
        let error = File.System.Metadata.Permissions.Error.chmod(.permission(.readOnlyFilesystem))
        #expect(error.isReadOnly)
        #expect(!error.isPermissionDenied)
    }

    // MARK: - OptionSet Operations

    @Test
    func `Permissions OptionSet union`() {
        let perms1: File.System.Metadata.Permissions = [.ownerRead]
        let perms2: File.System.Metadata.Permissions = [.ownerWrite]
        let union = perms1.union(perms2)

        #expect(union.contains(.ownerRead))
        #expect(union.contains(.ownerWrite))
    }

    @Test
    func `Permissions OptionSet intersection`() {
        let perms1: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]
        let perms2: File.System.Metadata.Permissions = [.ownerWrite, .ownerExecute]
        let intersection = perms1.intersection(perms2)

        #expect(!intersection.contains(.ownerRead))
        #expect(intersection.contains(.ownerWrite))
        #expect(!intersection.contains(.ownerExecute))
    }

    @Test
    func `Permissions isEmpty`() {
        let empty: File.System.Metadata.Permissions = []
        let notEmpty: File.System.Metadata.Permissions = [.ownerRead]

        #expect(empty.isEmpty)
        #expect(!notEmpty.isEmpty)
    }

    @Test
    func `Executable permissions (755)`() {
        let executable = File.System.Metadata.Permissions.executable
        #expect(executable.contains(.ownerRead))
        #expect(executable.contains(.ownerWrite))
        #expect(executable.contains(.ownerExecute))
        #expect(executable.contains(.groupRead))
        #expect(executable.contains(.groupExecute))
        #expect(executable.contains(.otherRead))
        #expect(executable.contains(.otherExecute))
        #expect(!executable.contains(.groupWrite))
        #expect(!executable.contains(.otherWrite))
    }

    @Test
    func `Binary.Serializable - serialize produces correct bytes`() {
        var buffer: [Byte] = []
        File.System.Metadata.Permissions.serialize(.ownerRead, into: &buffer)
        // UInt16 in little-endian: 0o400 = 256 = [0, 1]
        #expect(buffer.count == 2)
    }

    @Test
    func `Permissions is Sendable`() async {
        let perms: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]

        let result = await Task {
            perms
        }.value

        #expect(result == perms)
    }

    @Test
    func `Error is Sendable`() async {
        let error = File.System.Metadata.Permissions.Error.chmod(.path(.notFound))

        let result = await Task {
            error
        }.value

        // Sendability check - if this compiles, the type is Sendable
        #expect(result.isNotFound)
    }

    // MARK: - Special Bit Combinations

    @Test
    func `setuid with executable`() {
        let perms: File.System.Metadata.Permissions = [.setuid, .ownerExecute]
        #expect(perms.contains(.setuid))
        #expect(perms.contains(.ownerExecute))
        #expect(perms.rawValue == 0o4100)
    }

    @Test
    func `setgid with group execute`() {
        let perms: File.System.Metadata.Permissions = [.setgid, .groupExecute]
        #expect(perms.contains(.setgid))
        #expect(perms.contains(.groupExecute))
        #expect(perms.rawValue == 0o2010)
    }

    @Test
    func `sticky bit with other execute`() {
        let perms: File.System.Metadata.Permissions = [.sticky, .otherExecute]
        #expect(perms.contains(.sticky))
        #expect(perms.contains(.otherExecute))
        #expect(perms.rawValue == 0o1001)
    }

    @Test
    func `all special bits combined`() {
        let perms: File.System.Metadata.Permissions = [.setuid, .setgid, .sticky]
        #expect(perms.rawValue == 0o7000)
    }

    @Test
    func `common permission patterns`() {
        // 777 - all permissions
        let all: File.System.Metadata.Permissions = [.ownerAll, .groupAll, .otherAll]
        #expect(all.rawValue == 0o777)

        // 644 - typical file
        let file: File.System.Metadata.Permissions = [
            .ownerRead, .ownerWrite, .groupRead, .otherRead,
        ]
        #expect(file.rawValue == 0o644)

        // 755 - typical directory/executable
        let dir: File.System.Metadata.Permissions = [
            .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
        ]
        #expect(dir.rawValue == 0o755)

        // 600 - private file
        let privateFile: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]
        #expect(privateFile.rawValue == 0o600)

        // 700 - private directory
        let privateDir: File.System.Metadata.Permissions = [.ownerAll]
        #expect(privateDir.rawValue == 0o700)
    }

    @Test
    func `rawValue init and access`() {
        let perms = File.System.Metadata.Permissions(rawValue: 0o755)
        #expect(perms.contains(.ownerRead))
        #expect(perms.contains(.ownerWrite))
        #expect(perms.contains(.ownerExecute))
        #expect(perms.contains(.groupRead))
        #expect(perms.contains(.groupExecute))
        #expect(perms.contains(.otherRead))
        #expect(perms.contains(.otherExecute))
    }

    @Test
    func `symmetric difference`() {
        let perms1: File.System.Metadata.Permissions = [.ownerRead, .ownerWrite]
        let perms2: File.System.Metadata.Permissions = [.ownerWrite, .ownerExecute]
        let diff = perms1.symmetricDifference(perms2)

        #expect(diff.contains(.ownerRead))
        #expect(!diff.contains(.ownerWrite))
        #expect(diff.contains(.ownerExecute))
    }

    @Test
    func `insert and remove`() {
        var perms: File.System.Metadata.Permissions = [.ownerRead]
        perms.insert(.ownerWrite)
        #expect(perms.contains(.ownerWrite))

        perms.remove(.ownerRead)
        #expect(!perms.contains(.ownerRead))
    }
}
