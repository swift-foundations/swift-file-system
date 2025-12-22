//
//  File.System.Write.Streaming.Error Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Streaming.Error {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Error.Test.Unit {
    @Test("parent error - missing")
    func parentMissingCase() throws {
        let path = try File.Path("/nonexistent/parent")
        let parentError = File.System.Parent.Check.Error.missing(path: path)
        let error = File.System.Write.Streaming.Error.parent(parentError)

        if case .parent(let e) = error, case .missing(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.missing) case")
        }
    }

    @Test("parent error - notDirectory")
    func parentNotDirectoryCase() throws {
        let path = try File.Path("/some/file")
        let parentError = File.System.Parent.Check.Error.notDirectory(path: path)
        let error = File.System.Write.Streaming.Error.parent(parentError)

        if case .parent(let e) = error, case .notDirectory(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.notDirectory) case")
        }
    }

    @Test("parent error - accessDenied")
    func parentAccessDeniedCase() throws {
        let path = try File.Path("/protected/dir")
        let parentError = File.System.Parent.Check.Error.accessDenied(path: path)
        let error = File.System.Write.Streaming.Error.parent(parentError)

        if case .parent(let e) = error, case .accessDenied(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.accessDenied) case")
        }
    }

    @Test("fileCreationFailed case")
    func fileCreationFailedCase() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.fileCreationFailed(
            path: path,
            errno: 13,
            message: "Permission denied"
        )

        if case .fileCreationFailed(let p, let e, let m) = error {
            #expect(p == path)
            #expect(e == 13)
            #expect(m == "Permission denied")
        } else {
            Issue.record("Expected fileCreationFailed case")
        }
    }

    @Test("writeFailed case")
    func writeFailedCase() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.writeFailed(
            path: path,
            bytesWritten: 1024,
            errno: 28,
            message: "No space left on device"
        )

        if case .writeFailed(let p, let bytes, let e, let m) = error {
            #expect(p == path)
            #expect(bytes == 1024)
            #expect(e == 28)
            #expect(m == "No space left on device")
        } else {
            Issue.record("Expected writeFailed case")
        }
    }

    @Test("syncFailed case")
    func syncFailedCase() {
        let error = File.System.Write.Streaming.Error.syncFailed(
            errno: 5,
            message: "I/O error"
        )

        if case .syncFailed(let e, let m) = error {
            #expect(e == 5)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected syncFailed case")
        }
    }

    @Test("closeFailed case")
    func closeFailedCase() {
        let error = File.System.Write.Streaming.Error.closeFailed(
            errno: 9,
            message: "Bad file descriptor"
        )

        if case .closeFailed(let e, let m) = error {
            #expect(e == 9)
            #expect(m == "Bad file descriptor")
        } else {
            Issue.record("Expected closeFailed case")
        }
    }

    @Test("renameFailed case")
    func renameFailedCase() throws {
        let from = try File.Path("/tmp/temp.txt")
        let to = try File.Path("/tmp/final.txt")
        let error = File.System.Write.Streaming.Error.renameFailed(
            from: from,
            to: to,
            errno: 18,
            message: "Cross-device link"
        )

        if case .renameFailed(let f, let t, let e, let m) = error {
            #expect(f == from)
            #expect(t == to)
            #expect(e == 18)
            #expect(m == "Cross-device link")
        } else {
            Issue.record("Expected renameFailed case")
        }
    }

    @Test("destinationExists case")
    func destinationExistsCase() throws {
        let path = try File.Path("/tmp/existing.txt")
        let error = File.System.Write.Streaming.Error.destinationExists(path: path)

        if case .destinationExists(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected destinationExists case")
        }
    }

    @Test("directorySyncFailed case")
    func directorySyncFailedCase() throws {
        let path = try File.Path("/tmp")
        let error = File.System.Write.Streaming.Error.directorySyncFailed(
            path: path,
            errno: 5,
            message: "I/O error"
        )

        if case .directorySyncFailed(let p, let e, let m) = error {
            #expect(p == path)
            #expect(e == 5)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected directorySyncFailed case")
        }
    }

    @Test("durabilityNotGuaranteed case")
    func durabilityNotGuaranteedCase() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.durabilityNotGuaranteed(
            path: path,
            reason: "Cancelled during sync"
        )

        if case .durabilityNotGuaranteed(let p, let r) = error {
            #expect(p == path)
            #expect(r == "Cancelled during sync")
        } else {
            Issue.record("Expected durabilityNotGuaranteed case")
        }
    }

    @Test("directorySyncFailedAfterCommit case")
    func directorySyncFailedAfterCommitCase() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.directorySyncFailedAfterCommit(
            path: path,
            errno: 5,
            message: "I/O error"
        )

        if case .directorySyncFailedAfterCommit(let p, let e, let m) = error {
            #expect(p == path)
            #expect(e == 5)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected directorySyncFailedAfterCommit case")
        }
    }

    @Test("Error is Sendable")
    func errorIsSendable() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.destinationExists(path: path)
        Task {
            _ = error
        }
    }

    @Test("Error conforms to Swift.Error")
    func errorConformsToSwiftError() throws {
        let path = File.Path("/tmp/test.txt")
        let error: Swift.Error = File.System.Write.Streaming.Error.destinationExists(path: path)
        #expect(error is File.System.Write.Streaming.Error)
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Error.Test.EdgeCase {
    @Test("Equatable conformance")
    func equatableConformance() throws {
        let path = File.Path("/tmp/test.txt")
        let error1 = File.System.Write.Streaming.Error.destinationExists(path: path)
        let error2 = File.System.Write.Streaming.Error.destinationExists(path: path)
        let parentError = File.System.Parent.Check.Error.missing(path: path)
        let error3 = File.System.Write.Streaming.Error.parent(parentError)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("description for parent error")
    func descriptionParentError() throws {
        let path = try File.Path("/nonexistent/parent")
        let parentError = File.System.Parent.Check.Error.missing(path: path)
        let error = File.System.Write.Streaming.Error.parent(parentError)
        #expect(error.description.contains("Parent directory"))
    }

    @Test("description for destinationExists")
    func descriptionDestinationExists() throws {
        let path = File.Path("/tmp/existing.txt")
        let error = File.System.Write.Streaming.Error.destinationExists(path: path)
        #expect(error.description.contains("Destination already exists"))
        #expect(error.description.contains("noClobber"))
    }

    @Test("description for writeFailed includes bytesWritten")
    func descriptionWriteFailedIncludesBytes() throws {
        let path = File.Path("/tmp/test.txt")
        let error = File.System.Write.Streaming.Error.writeFailed(
            path: path,
            bytesWritten: 1024,
            errno: 28,
            message: "No space"
        )
        #expect(error.description.contains("1024"))
    }
}
