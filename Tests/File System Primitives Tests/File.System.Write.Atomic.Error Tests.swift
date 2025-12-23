//
//  File.System.Write.Atomic.Error Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Error {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Error.Test.Unit {
    @Test("Error.parent - missing")
    func errorParentMissing() {
        let path: File.Path = "/nonexistent/parent"
        let parentError = File.System.Parent.Check.Error.missing(path: path)
        let error = File.System.Write.Atomic.Error.parent(parentError)

        if case .parent(let e) = error, case .missing(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.missing) error")
        }

        #expect(error.description.contains("Parent directory"))
    }

    @Test("Error.parent - notDirectory")
    func errorParentNotDirectory() {
        let path: File.Path = "/tmp/file.txt"
        let parentError = File.System.Parent.Check.Error.notDirectory(path: path)
        let error = File.System.Write.Atomic.Error.parent(parentError)

        if case .parent(let e) = error, case .notDirectory(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.notDirectory) error")
        }

        #expect(error.description.contains("not a directory"))
    }

    @Test("Error.parent - accessDenied")
    func errorParentAccessDenied() {
        let path: File.Path = "/protected"
        let parentError = File.System.Parent.Check.Error.accessDenied(path: path)
        let error = File.System.Write.Atomic.Error.parent(parentError)

        if case .parent(let e) = error, case .accessDenied(let p) = e {
            #expect(p == path)
        } else {
            Issue.record("Expected parent(.accessDenied) error")
        }

        #expect(error.description.contains("Access denied"))
    }

    @Test("Error.destinationExists")
    func errorDestinationExists() {
        let path: File.Path = "/tmp/existing.txt"
        let error = File.System.Write.Atomic.Error.destinationExists(path: path)

        if case .destinationExists(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected destinationExists error")
        }

        #expect(error.description.contains("already exists"))
        #expect(error.description.contains("noClobber"))
    }

    @Test("Error.writeFailed")
    func errorWriteFailed() {
        let code = File.System.Error.Code.posix(28)
        let error = File.System.Write.Atomic.Error.writeFailed(
            bytesWritten: 100,
            bytesExpected: 1000,
            code: code,
            message: "No space left"
        )

        if case .writeFailed(let written, let expected, let c, let msg) = error {
            #expect(written == 100)
            #expect(expected == 1000)
            #expect(c == code)
            #expect(msg == "No space left")
        } else {
            Issue.record("Expected writeFailed error")
        }

        #expect(error.description.contains("100"))
        #expect(error.description.contains("1000"))
    }

    @Test("Error.syncFailed")
    func errorSyncFailed() {
        let code = File.System.Error.Code.posix(5)
        let error = File.System.Write.Atomic.Error.syncFailed(
            code: code,
            message: "I/O error"
        )

        if case .syncFailed(let c, let msg) = error {
            #expect(c == code)
            #expect(msg == "I/O error")
        } else {
            Issue.record("Expected syncFailed error")
        }

        #expect(error.description.contains("Sync failed"))
    }

    @Test("Error.renameFailed")
    func errorRenameFailed() {
        let from: File.Path = "/tmp/temp.txt"
        let to: File.Path = "/tmp/dest.txt"
        let code = File.System.Error.Code.posix(18)
        let error = File.System.Write.Atomic.Error.renameFailed(
            from: from,
            to: to,
            code: code,
            message: "Cross-device link"
        )

        if case .renameFailed(let f, let t, let c, let msg) = error {
            #expect(f == from)
            #expect(t == to)
            #expect(c == code)
            #expect(msg == "Cross-device link")
        } else {
            Issue.record("Expected renameFailed error")
        }

        #expect(error.description.contains("Rename failed"))
        #expect(error.description.contains("→"))
    }

    @Test("Error.platformIncompatible")
    func errorPlatformIncompatible() {
        let error = File.System.Write.Atomic.Error.platformIncompatible(
            operation: "O_TMPFILE",
            message: "Kernel too old"
        )

        if case .platformIncompatible(let op, let msg) = error {
            #expect(op == "O_TMPFILE")
            #expect(msg == "Kernel too old")
        } else {
            Issue.record("Expected platformIncompatible error")
        }

        #expect(error.description.contains("Platform incompatible"))
    }

    @Test("Error is Equatable")
    func errorIsEquatable() {
        let path: File.Path = "/test"
        let parentError1 = File.System.Parent.Check.Error.missing(path: path)
        let parentError2 = File.System.Parent.Check.Error.notDirectory(path: path)
        let error1 = File.System.Write.Atomic.Error.parent(parentError1)
        let error2 = File.System.Write.Atomic.Error.parent(parentError1)
        let error3 = File.System.Write.Atomic.Error.parent(parentError2)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Error is Sendable")
    func errorIsSendable() {
        let path: File.Path = "/test"
        let parentError = File.System.Parent.Check.Error.missing(path: path)
        let error: File.System.Write.Atomic.Error = .parent(parentError)
        Task {
            _ = error
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Error.Test.EdgeCase {
    @Test("Error.writeFailed with zero bytes")
    func errorWriteFailedZeroBytes() {
        let error = File.System.Write.Atomic.Error.writeFailed(
            bytesWritten: 0,
            bytesExpected: 0,
            code: .posix(0),
            message: ""
        )

        if case .writeFailed(let written, let expected, _, _) = error {
            #expect(written == 0)
            #expect(expected == 0)
        } else {
            Issue.record("Expected writeFailed error")
        }
    }

    @Test("Error.directorySyncFailedAfterCommit")
    func errorDirectorySyncFailedAfterCommit() {
        let path: File.Path = "/tmp/committed.txt"
        let code = File.System.Error.Code.posix(5)
        let error = File.System.Write.Atomic.Error.directorySyncFailedAfterCommit(
            path: path,
            code: code,
            message: "Sync failed after commit"
        )

        if case .directorySyncFailedAfterCommit(let p, let c, let msg) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(msg == "Sync failed after commit")
        } else {
            Issue.record("Expected directorySyncFailedAfterCommit error")
        }

        #expect(error.description.contains("after commit"))
    }

    @Test("Error.randomGenerationFailed")
    func errorRandomGenerationFailed() {
        let code = File.System.Error.Code.posix(38)
        let error = File.System.Write.Atomic.Error.randomGenerationFailed(
            code: code,
            operation: "getrandom",
            message: "CSPRNG failure"
        )

        if case .randomGenerationFailed(let c, let op, let msg) = error {
            #expect(c == code)
            #expect(op == "getrandom")
            #expect(msg == "CSPRNG failure")
        } else {
            Issue.record("Expected randomGenerationFailed error")
        }

        #expect(error.description.contains("Random generation failed"))
    }
}
