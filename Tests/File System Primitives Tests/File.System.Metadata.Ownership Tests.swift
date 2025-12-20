//
//  File.System.Metadata.Ownership Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if canImport(Foundation)
    import Foundation
#endif

extension File.System.Metadata.Ownership {
    #TestSuites
}

extension File.System.Metadata.Ownership.Test.Unit {

    // MARK: - Test Fixtures

    private func createTempFile() throws -> String {
        #if canImport(Foundation)
            let path = "/tmp/ownership-test-\(Int.random(in: 0..<Int.max)).txt"
            FileManager.default.createFile(atPath: path, contents: nil)
            return path
        #else
            let path = "/tmp/ownership-test-\(Int.random(in: 0..<Int.max)).txt"
            let filePath = try File.Path(path)
            try [].withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: filePath)
            }
            return path
        #endif
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath)
        }
    }

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
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let ownership = try File.System.Metadata.Ownership(at: filePath)

        // Current user should own the file
        #expect(ownership.uid == getuid())
        // GID inherits from parent directory, not necessarily user's primary group
        // Verify we get the same value as stat
        var statBuf = stat()
        _ = stat(path, &statBuf)
        #expect(ownership.gid == statBuf.st_gid)
    }

    @Test("Get ownership of system file")
    func getOwnershipOfSystemFile() throws {
        // /etc/passwd should be owned by root (uid 0)
        let filePath = try File.Path("/etc/passwd")
        let ownership = try File.System.Metadata.Ownership(at: filePath)

        #expect(ownership.uid == 0)
    }

    // MARK: - Set Ownership (limited tests due to permission requirements)

    @Test("Set ownership to same owner succeeds")
    func setOwnershipToSameOwner() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let currentOwnership = try File.System.Metadata.Ownership(at: filePath)

        // Setting to same ownership should succeed (no-op)
        try File.System.Metadata.Ownership.set(currentOwnership, at: filePath)

        let afterSet = try File.System.Metadata.Ownership(at: filePath)
        #expect(afterSet.uid == currentOwnership.uid)
        #expect(afterSet.gid == currentOwnership.gid)
    }

    // MARK: - Error Cases

    @Test("Get ownership of non-existent file throws pathNotFound")
    func getOwnershipOfNonExistentFileThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)

        #expect(throws: File.System.Metadata.Ownership.Error.pathNotFound(path)) {
            _ = try File.System.Metadata.Ownership(at: path)
        }
    }

    @Test("Set ownership of non-existent file throws pathNotFound")
    func setOwnershipOfNonExistentFileThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)

        let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

        #expect(throws: File.System.Metadata.Ownership.Error.pathNotFound(path)) {
            try File.System.Metadata.Ownership.set(ownership, at: path)
        }
    }

    // MARK: - Error Descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = try File.Path("/tmp/missing")
        let error = File.System.Metadata.Ownership.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = try File.Path("/root/secret")
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
