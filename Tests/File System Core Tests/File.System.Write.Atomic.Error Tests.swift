//
//  File.System.Write.Atomic.Error Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Atomic.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Error.Test.Unit {
    @Test
    func `Error.parentVerificationFailed`() {
        let path: File.Path = "/nonexistent/parent"
        let code = Error_Primitives.Error.Code.posix(2)
        let error = File.System.Write.Atomic.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "No such file or directory"
        )

        if case .parentVerificationFailed(let p, let c, let msg) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(msg == "No such file or directory")
        } else {
            Issue.record("Expected parentVerificationFailed error")
        }

        #expect(error.description.contains("Parent directory"))
    }

    @Test
    func `Error.destinationStatFailed`() {
        let path: File.Path = "/tmp/dest.txt"
        let code = Error_Primitives.Error.Code.posix(2)
        let error = File.System.Write.Atomic.Error.destinationStatFailed(
            path: path,
            code: code,
            message: "No such file or directory"
        )

        if case .destinationStatFailed(let p, let c, let msg) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(msg == "No such file or directory")
        } else {
            Issue.record("Expected destinationStatFailed error")
        }

        #expect(error.description.contains("stat destination"))
    }

    @Test
    func `Error.tempFileCreationFailed`() {
        let directory: File.Path = "/tmp"
        let code = Error_Primitives.Error.Code.posix(13)
        let error = File.System.Write.Atomic.Error.tempFileCreationFailed(
            directory: directory,
            code: code,
            message: "Permission denied"
        )

        if case .tempFileCreationFailed(let d, let c, let msg) = error {
            #expect(d == directory)
            #expect(c == code)
            #expect(msg == "Permission denied")
        } else {
            Issue.record("Expected tempFileCreationFailed error")
        }

        #expect(error.description.contains("temp file"))
    }

    @Test
    func `Error.destinationExists`() {
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

    @Test
    func `Error.writeFailed`() {
        let code = Error_Primitives.Error.Code.posix(28)
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

    @Test
    func `Error.syncFailed`() {
        let code = Error_Primitives.Error.Code.posix(5)
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

    @Test
    func `Error.closeFailed`() {
        let code = Error_Primitives.Error.Code.posix(9)
        let error = File.System.Write.Atomic.Error.closeFailed(
            code: code,
            message: "Bad file descriptor"
        )

        if case .closeFailed(let c, let msg) = error {
            #expect(c == code)
            #expect(msg == "Bad file descriptor")
        } else {
            Issue.record("Expected closeFailed error")
        }

        #expect(error.description.contains("Close failed"))
    }

    @Test
    func `Error.renameFailed`() {
        let from: File.Path = "/tmp/temp.txt"
        let to: File.Path = "/tmp/dest.txt"
        let code = Error_Primitives.Error.Code.posix(18)
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
        #expect(error.description.contains("\u{2192}"))
    }

    @Test
    func `Error.platformIncompatible`() {
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

    @Test
    func `Error.metadataPreservationFailed`() {
        let code = Error_Primitives.Error.Code.posix(1)
        let error = File.System.Write.Atomic.Error.metadataPreservationFailed(
            operation: "fchmod",
            code: code,
            message: "Operation not permitted"
        )

        if case .metadataPreservationFailed(let op, let c, let msg) = error {
            #expect(op == "fchmod")
            #expect(c == code)
            #expect(msg == "Operation not permitted")
        } else {
            Issue.record("Expected metadataPreservationFailed error")
        }

        #expect(error.description.contains("Metadata preservation failed"))
    }

    @Test
    func `Error is Equatable`() {
        let path: File.Path = "/test"
        let code = Error_Primitives.Error.Code.posix(2)
        let error1 = File.System.Write.Atomic.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "missing"
        )
        let error2 = File.System.Write.Atomic.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "missing"
        )
        let error3 = File.System.Write.Atomic.Error.destinationExists(path: path)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test
    func `Error is Sendable`() {
        let error: File.System.Write.Atomic.Error = .destinationExists(path: "/test")
        Task {
            _ = error
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Error.Test.`Edge Case` {
    @Test
    func `Error.writeFailed with zero bytes`() {
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

    @Test
    func `Error.directorySyncFailedAfterCommit`() {
        let path: File.Path = "/tmp/committed.txt"
        let code = Error_Primitives.Error.Code.posix(5)
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

    @Test
    func `Error.randomGenerationFailed`() {
        let code = Error_Primitives.Error.Code.posix(38)
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

    @Test
    func `Error.directorySyncFailed`() {
        let path: File.Path = "/tmp"
        let code = Error_Primitives.Error.Code.posix(5)
        let error = File.System.Write.Atomic.Error.directorySyncFailed(
            path: path,
            code: code,
            message: "I/O error"
        )

        if case .directorySyncFailed(let p, let c, let msg) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(msg == "I/O error")
        } else {
            Issue.record("Expected directorySyncFailed error")
        }

        #expect(error.description.contains("Directory sync failed"))
    }
}
