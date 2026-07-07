//
//  File.System.Write.Streaming.Error Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Error.Test.Unit {
    @Test
    func `parentVerificationFailed case`() {
        let path: File.Path = "/nonexistent/parent"
        let code = Error_Primitives.Error.Code.posix(2)
        let error = File.System.Write.Streaming.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "No such file or directory"
        )

        if case .parentVerificationFailed(let p, let c, let msg) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(msg == "No such file or directory")
        } else {
            Issue.record("Expected parentVerificationFailed case")
        }
    }

    @Test
    func `fileCreationFailed case`() {
        let path: File.Path = "/tmp/test.txt"
        let code = Error_Primitives.Error.Code.posix(13)
        let error = File.System.Write.Streaming.Error.fileCreationFailed(
            path: path,
            code: code,
            message: "Permission denied"
        )

        if case .fileCreationFailed(let p, let c, let m) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(m == "Permission denied")
        } else {
            Issue.record("Expected fileCreationFailed case")
        }
    }

    @Test
    func `writeFailed case`() {
        let code = Error_Primitives.Error.Code.posix(28)
        let error = File.System.Write.Streaming.Error.writeFailed(
            bytesWritten: 1024,
            code: code,
            message: "No space left on device"
        )

        if case .writeFailed(let bytes, let c, let m) = error {
            #expect(bytes == 1024)
            #expect(c == code)
            #expect(m == "No space left on device")
        } else {
            Issue.record("Expected writeFailed case")
        }
    }

    @Test
    func `syncFailed case`() {
        let code = Error_Primitives.Error.Code.posix(5)
        let error = File.System.Write.Streaming.Error.syncFailed(
            code: code,
            message: "I/O error"
        )

        if case .syncFailed(let c, let m) = error {
            #expect(c == code)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected syncFailed case")
        }
    }

    @Test
    func `closeFailed case`() {
        let code = Error_Primitives.Error.Code.posix(9)
        let error = File.System.Write.Streaming.Error.closeFailed(
            code: code,
            message: "Bad file descriptor"
        )

        if case .closeFailed(let c, let m) = error {
            #expect(c == code)
            #expect(m == "Bad file descriptor")
        } else {
            Issue.record("Expected closeFailed case")
        }
    }

    @Test
    func `renameFailed case`() {
        let from: File.Path = "/tmp/temp.txt"
        let to: File.Path = "/tmp/final.txt"
        let code = Error_Primitives.Error.Code.posix(18)
        let error = File.System.Write.Streaming.Error.renameFailed(
            from: from,
            to: to,
            code: code,
            message: "Cross-device link"
        )

        if case .renameFailed(let f, let t, let c, let m) = error {
            #expect(f == from)
            #expect(t == to)
            #expect(c == code)
            #expect(m == "Cross-device link")
        } else {
            Issue.record("Expected renameFailed case")
        }
    }

    @Test
    func `destinationExists case`() {
        let path: File.Path = "/tmp/existing.txt"
        let error = File.System.Write.Streaming.Error.destinationExists(path: path)

        if case .destinationExists(let p) = error {
            #expect(p == path)
        } else {
            Issue.record("Expected destinationExists case")
        }
    }

    @Test
    func `directorySyncFailed case`() {
        let path: File.Path = "/tmp"
        let code = Error_Primitives.Error.Code.posix(5)
        let error = File.System.Write.Streaming.Error.directorySyncFailed(
            path: path,
            code: code,
            message: "I/O error"
        )

        if case .directorySyncFailed(let p, let c, let m) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected directorySyncFailed case")
        }
    }

    @Test
    func `durabilityNotGuaranteed case`() {
        let path: File.Path = "/tmp/test.txt"
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

    @Test
    func `directorySyncFailedAfterCommit case`() {
        let path: File.Path = "/tmp/test.txt"
        let code = Error_Primitives.Error.Code.posix(5)
        let error = File.System.Write.Streaming.Error.directorySyncFailedAfterCommit(
            path: path,
            code: code,
            message: "I/O error"
        )

        if case .directorySyncFailedAfterCommit(let p, let c, let m) = error {
            #expect(p == path)
            #expect(c == code)
            #expect(m == "I/O error")
        } else {
            Issue.record("Expected directorySyncFailedAfterCommit case")
        }
    }

    @Test
    func `invalidState case`() {
        let error = File.System.Write.Streaming.Error.invalidState

        if case .invalidState = error {
            // pass
        } else {
            Issue.record("Expected invalidState case")
        }
    }

    @Test
    func `randomGenerationFailed case`() {
        let code = Error_Primitives.Error.Code.posix(38)
        let error = File.System.Write.Streaming.Error.randomGenerationFailed(
            code: code,
            message: "CSPRNG failure"
        )

        if case .randomGenerationFailed(let c, let m) = error {
            #expect(c == code)
            #expect(m == "CSPRNG failure")
        } else {
            Issue.record("Expected randomGenerationFailed case")
        }
    }

    @Test
    func `userError case`() {
        let error = File.System.Write.Streaming.Error.userError(
            message: "Custom error from closure"
        )

        if case .userError(let m) = error {
            #expect(m == "Custom error from closure")
        } else {
            Issue.record("Expected userError case")
        }
    }

    @Test
    func `invalidFillResult case`() {
        let error = File.System.Write.Streaming.Error.invalidFillResult(
            produced: 8192,
            capacity: 4096
        )

        if case .invalidFillResult(let produced, let capacity) = error {
            #expect(produced == 8192)
            #expect(capacity == 4096)
        } else {
            Issue.record("Expected invalidFillResult case")
        }
    }

    @Test
    func `Error is Sendable`() {
        let error: File.System.Write.Streaming.Error = .destinationExists(path: "/tmp/test.txt")
        Task {
            _ = error
        }
    }

    @Test
    func `Error conforms to Swift.Error`() {
        let error: any Swift.Error = File.System.Write.Streaming.Error.destinationExists(path: "/tmp/test.txt")
        #expect(error is File.System.Write.Streaming.Error)
    }
}

// MARK: - Edge Cases

extension File.System.Write.Streaming.Error.Test.`Edge Case` {
    @Test
    func `Equatable conformance`() {
        let path: File.Path = "/tmp/test.txt"
        let error1 = File.System.Write.Streaming.Error.destinationExists(path: path)
        let error2 = File.System.Write.Streaming.Error.destinationExists(path: path)
        let code = Error_Primitives.Error.Code.posix(2)
        let error3 = File.System.Write.Streaming.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "missing"
        )

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test
    func `description for parentVerificationFailed`() {
        let path: File.Path = "/nonexistent/parent"
        let code = Error_Primitives.Error.Code.posix(2)
        let error = File.System.Write.Streaming.Error.parentVerificationFailed(
            path: path,
            code: code,
            message: "No such file or directory"
        )
        #expect(error.description.contains("Parent directory"))
    }

    @Test
    func `description for destinationExists`() {
        let path: File.Path = "/tmp/existing.txt"
        let error = File.System.Write.Streaming.Error.destinationExists(path: path)
        #expect(error.description.contains("Destination already exists"))
        #expect(error.description.contains("noClobber"))
    }

    @Test
    func `description for writeFailed includes bytesWritten`() {
        let code = Error_Primitives.Error.Code.posix(28)
        let error = File.System.Write.Streaming.Error.writeFailed(
            bytesWritten: 1024,
            code: code,
            message: "No space"
        )
        #expect(error.description.contains("1024"))
    }
}
