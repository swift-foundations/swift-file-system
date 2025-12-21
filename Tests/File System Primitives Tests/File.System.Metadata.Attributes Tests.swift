//
//  File.System.Metadata.Attributes Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Metadata.Attributes {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Metadata.Attributes.Test.Unit {
    // File.System.Metadata.Attributes is a namespace with Error type

    @Test("Attributes namespace exists")
    func attributesNamespaceExists() {
        _ = File.System.Metadata.Attributes.self
        _ = File.System.Metadata.Attributes.Error.self
    }
}

// MARK: - Error Tests

extension File.System.Metadata.Attributes.Test.Unit {
    @Test("Error.pathNotFound")
    func errorPathNotFound() throws {
        let path = try File.Path("/nonexistent")
        let error = File.System.Metadata.Attributes.Error.pathNotFound(path)

        if case .pathNotFound(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected pathNotFound error")
        }
    }

    @Test("Error.permissionDenied")
    func errorPermissionDenied() throws {
        let path = try File.Path("/protected")
        let error = File.System.Metadata.Attributes.Error.permissionDenied(path)

        if case .permissionDenied(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected permissionDenied error")
        }
    }

    @Test("Error.attributeNotFound")
    func errorAttributeNotFound() throws {
        let path = try File.Path("/tmp/file.txt")
        let error = File.System.Metadata.Attributes.Error.attributeNotFound(
            name: "user.custom",
            path: path
        )

        if case .attributeNotFound(let name, let p) = error {
            #expect(name == "user.custom")
            #expect(p == path)
        } else {
            Issue.record("Expected attributeNotFound error")
        }
    }

    @Test("Error.notSupported")
    func errorNotSupported() throws {
        let path = try File.Path("/tmp/file.txt")
        let error = File.System.Metadata.Attributes.Error.notSupported(path)

        if case .notSupported(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected notSupported error")
        }
    }

    @Test("Error.operationFailed")
    func errorOperationFailed() {
        let error = File.System.Metadata.Attributes.Error.operationFailed(
            errno: 5,
            message: "I/O error"
        )

        if case .operationFailed(let errno, let message) = error {
            #expect(errno == 5)
            #expect(message == "I/O error")
        } else {
            Issue.record("Expected operationFailed error")
        }
    }

    @Test("Error is Equatable")
    func errorIsEquatable() throws {
        let path = try File.Path("/test")
        let error1 = File.System.Metadata.Attributes.Error.pathNotFound(path)
        let error2 = File.System.Metadata.Attributes.Error.pathNotFound(path)
        let error3 = File.System.Metadata.Attributes.Error.permissionDenied(path)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Error is Sendable")
    func errorIsSendable() throws {
        let path = try File.Path("/test")
        let error: File.System.Metadata.Attributes.Error = .pathNotFound(path)

        // Verify Sendable conformance by using in async context
        Task {
            _ = error
        }
    }
}

// MARK: - Edge Cases

extension File.System.Metadata.Attributes.Test.EdgeCase {
    @Test("Error with empty attribute name")
    func errorWithEmptyAttributeName() throws {
        let path = try File.Path("/tmp/file.txt")
        let error = File.System.Metadata.Attributes.Error.attributeNotFound(
            name: "",
            path: path
        )

        if case .attributeNotFound(let name, _) = error {
            #expect(name.isEmpty)
        } else {
            Issue.record("Expected attributeNotFound error")
        }
    }

    @Test("Error with unicode attribute name")
    func errorWithUnicodeAttributeName() throws {
        let path = try File.Path("/tmp/file.txt")
        let error = File.System.Metadata.Attributes.Error.attributeNotFound(
            name: "user.日本語",
            path: path
        )

        if case .attributeNotFound(let name, _) = error {
            #expect(name == "user.日本語")
        } else {
            Issue.record("Expected attributeNotFound error")
        }
    }
}
