//
//  File.System.Create.File Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Create.File {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Create.File.Test.Unit {
    // File.System.Create.File is a namespace with Error type

    @Test("File namespace exists")
    func fileNamespaceExists() {
        _ = File.System.Create.File.self
        _ = File.System.Create.File.Error.self
    }
}

// MARK: - Error Tests

extension File.System.Create.File.Test.Unit {
    @Test("Error.alreadyExists")
    func errorAlreadyExists() throws {
        let path = try File_System_Primitives.File.Path("/tmp/existing.txt")
        let error = File.System.Create.File.Error.alreadyExists(path)

        if case .alreadyExists(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected alreadyExists error")
        }
    }

    @Test("Error.permissionDenied")
    func errorPermissionDenied() throws {
        let path = try File_System_Primitives.File.Path("/protected/file.txt")
        let error = File.System.Create.File.Error.permissionDenied(path)

        if case .permissionDenied(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected permissionDenied error")
        }
    }

    @Test("Error.parentDirectoryNotFound")
    func errorParentDirectoryNotFound() throws {
        let path = try File_System_Primitives.File.Path("/nonexistent/dir/file.txt")
        let error = File.System.Create.File.Error.parentDirectoryNotFound(path)

        if case .parentDirectoryNotFound(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected parentDirectoryNotFound error")
        }
    }

    @Test("Error.createFailed")
    func errorCreateFailed() {
        let error = File.System.Create.File.Error.createFailed(
            errno: 28,
            message: "No space left on device"
        )

        if case .createFailed(let errno, let message) = error {
            #expect(errno == 28)
            #expect(message == "No space left on device")
        } else {
            Issue.record("Expected createFailed error")
        }
    }

    @Test("Error is Equatable")
    func errorIsEquatable() throws {
        let path = try File_System_Primitives.File.Path("/test")
        let error1 = File.System.Create.File.Error.alreadyExists(path)
        let error2 = File.System.Create.File.Error.alreadyExists(path)
        let error3 = File.System.Create.File.Error.permissionDenied(path)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Error is Sendable")
    func errorIsSendable() throws {
        let path = try File_System_Primitives.File.Path("/test")
        let error: File.System.Create.File.Error = .alreadyExists(path)
        Task {
            _ = error
        }
    }
}

// MARK: - Edge Cases

extension File.System.Create.File.Test.EdgeCase {
    @Test("Error with root path")
    func errorWithRootPath() throws {
        let path = try File_System_Primitives.File.Path("/")
        let error = File.System.Create.File.Error.alreadyExists(path)

        if case .alreadyExists(let p) = error {
            #expect(p.string == "/")
        } else {
            Issue.record("Expected alreadyExists error")
        }
    }

    @Test("Error createFailed with zero errno")
    func errorCreateFailedWithZeroErrno() {
        let error = File.System.Create.File.Error.createFailed(
            errno: 0,
            message: "Success"
        )

        if case .createFailed(let errno, _) = error {
            #expect(errno == 0)
        } else {
            Issue.record("Expected createFailed error")
        }
    }

    @Test("Error createFailed with empty message")
    func errorCreateFailedWithEmptyMessage() {
        let error = File.System.Create.File.Error.createFailed(
            errno: 1,
            message: ""
        )

        if case .createFailed(_, let message) = error {
            #expect(message == "")
        } else {
            Issue.record("Expected createFailed error")
        }
    }
}
