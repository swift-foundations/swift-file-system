//
//  File.System.Metadata.Ownership Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

extension File.System.Metadata.Ownership {
    #TestSuites
}

extension File.System.Metadata.Ownership.Test.Unit {

    // MARK: - Initialization

    @Test("Ownership initialization")
    func ownershipInitialization() {
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)

        #expect(ownership.uid == 501)
        #expect(ownership.gid == 20)
    }

    // MARK: - Get Ownership

    @Test("Get ownership of file")
    func getOwnershipOfFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")
            let empty: [UInt8] = []
            try File.System.Write.Atomic.write(empty.span, to: filePath)

            let ownership = try File.System.Metadata.Ownership(at: filePath)

            // Current user should own the file
            #expect(ownership.uid == getuid())
            // GID inherits from parent directory, not necessarily user's primary group
            // Verify we get the same value as stat
            var statBuf = stat()
            _ = stat(filePath.string, &statBuf)
            #expect(ownership.gid == statBuf.st_gid)
        }
    }

    @Test("Get ownership of system file")
    func getOwnershipOfSystemFile() throws {
        // /etc/passwd should be owned by root (uid 0)
        let filePath = File.Path("/etc/passwd")
        let ownership = try File.System.Metadata.Ownership(at: filePath)

        #expect(ownership.uid == 0)
    }

    // MARK: - Set Ownership (limited tests due to permission requirements)

    @Test("Set ownership to same owner succeeds")
    func setOwnershipToSameOwner() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test.txt")
            let empty: [UInt8] = []
            try File.System.Write.Atomic.write(empty.span, to: filePath)

            let currentOwnership = try File.System.Metadata.Ownership(at: filePath)

            // Setting to same ownership should succeed (no-op)
            try File.System.Metadata.Ownership.set(currentOwnership, at: filePath)

            let afterSet = try File.System.Metadata.Ownership(at: filePath)
            #expect(afterSet.uid == currentOwnership.uid)
            #expect(afterSet.gid == currentOwnership.gid)
        }
    }

    // MARK: - Error Cases

    @Test("Get ownership of non-existent file throws pathNotFound")
    func getOwnershipOfNonExistentFileThrows() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "non-existent.txt")

            #expect(throws: File.System.Metadata.Ownership.Error.pathNotFound(path)) {
                _ = try File.System.Metadata.Ownership(at: path)
            }
        }
    }

    @Test("Set ownership of non-existent file throws pathNotFound")
    func setOwnershipOfNonExistentFileThrows() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "non-existent.txt")

            let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

            #expect(throws: File.System.Metadata.Ownership.Error.pathNotFound(path)) {
                try File.System.Metadata.Ownership.set(ownership, at: path)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.System.Metadata.Ownership.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
        let error = File.System.Metadata.Ownership.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("operationFailed error description")
    func operationFailedErrorDescription() {
        let error = File.System.Metadata.Ownership.Error.operationFailed(
            errno: 22,
            message: "Invalid argument"
        )
        #expect(error.description.contains("Operation failed"))
    }

    // MARK: - Equatable

    @Test("Ownership is equatable")
    func ownershipIsEquatable() {
        let ownership1 = File.System.Metadata.Ownership(uid: 501, gid: 20)
        let ownership2 = File.System.Metadata.Ownership(uid: 501, gid: 20)
        let ownership3 = File.System.Metadata.Ownership(uid: 502, gid: 20)

        #expect(ownership1 == ownership2)
        #expect(ownership1 != ownership3)
    }

    // MARK: - Sendable

    @Test("Ownership is sendable")
    func ownershipIsSendable() async {
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)

        await Task {
            #expect(ownership.uid == 501)
            #expect(ownership.gid == 20)
        }.value
    }
}
