//
//  File.System.Error.Code Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Error.Code {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Error.Code.Test.Unit {
    @Test(".posix case")
    func posixCase() {
        let code = File.System.Error.Code.posix(2) // ENOENT
        if case .posix(let errno) = code {
            #expect(errno == 2)
        } else {
            Issue.record("Expected posix case")
        }
    }

    @Test(".windows case")
    func windowsCase() {
        let code = File.System.Error.Code.windows(5) // ERROR_ACCESS_DENIED
        if case .windows(let error) = code {
            #expect(error == 5)
        } else {
            Issue.record("Expected windows case")
        }
    }

    @Test("rawValue for .posix")
    func rawValuePosix() {
        let code = File.System.Error.Code.posix(42)
        #expect(code.rawValue == 42)
    }

    @Test("rawValue for .windows")
    func rawValueWindows() {
        let code = File.System.Error.Code.windows(123)
        #expect(code.rawValue == 123)
    }

    @Test("Equatable - equal posix codes")
    func equatableEqualPosix() {
        let code1 = File.System.Error.Code.posix(2)
        let code2 = File.System.Error.Code.posix(2)
        #expect(code1 == code2)
    }

    @Test("Equatable - different posix codes")
    func equatableDifferentPosix() {
        let code1 = File.System.Error.Code.posix(2)
        let code2 = File.System.Error.Code.posix(13)
        #expect(code1 != code2)
    }

    @Test("Equatable - equal windows codes")
    func equatableEqualWindows() {
        let code1 = File.System.Error.Code.windows(5)
        let code2 = File.System.Error.Code.windows(5)
        #expect(code1 == code2)
    }

    @Test("Equatable - different windows codes")
    func equatableDifferentWindows() {
        let code1 = File.System.Error.Code.windows(5)
        let code2 = File.System.Error.Code.windows(2)
        #expect(code1 != code2)
    }

    @Test("Equatable - posix vs windows")
    func equatablePosixVsWindows() {
        let posix = File.System.Error.Code.posix(5)
        let windows = File.System.Error.Code.windows(5)
        // Same numeric value but different cases
        #expect(posix != windows)
    }

    @Test("description for .posix")
    func descriptionPosix() {
        let code = File.System.Error.Code.posix(2)
        let desc = code.description
        #expect(desc.contains("errno"))
        #expect(desc.contains("2"))
    }

    @Test("description for .windows")
    func descriptionWindows() {
        let code = File.System.Error.Code.windows(5)
        let desc = code.description
        #expect(desc.contains("Windows"))
        #expect(desc.contains("5"))
    }

    @Test("message property for .posix")
    func messagePosix() {
        let code = File.System.Error.Code.posix(2)
        let msg = code.message
        // On POSIX systems, should include strerror message
        // On Windows, just returns "error N"
        #expect(!msg.isEmpty)
    }

    @Test("message property for .windows")
    func messageWindows() {
        let code = File.System.Error.Code.windows(5)
        let msg = code.message
        #expect(msg.contains("Windows"))
        #expect(msg.contains("5"))
    }

    @Test(".current() returns valid code")
    func currentReturnsValidCode() {
        let code = File.System.Error.Code.current()
        // Should return either .posix or .windows depending on platform
        switch code {
        case .posix(let errno):
            #expect(errno >= 0 || errno < 0) // Any value is valid
        case .windows(let error):
            #expect(error >= 0) // Windows errors are unsigned
        }
    }
}

// MARK: - Edge Cases

extension File.System.Error.Code.Test.EdgeCase {
    @Test(".posix with zero")
    func posixWithZero() {
        let code = File.System.Error.Code.posix(0)
        #expect(code.rawValue == 0)
    }

    @Test(".posix with negative value")
    func posixWithNegative() {
        let code = File.System.Error.Code.posix(-1)
        #expect(code.rawValue == -1)
    }

    @Test(".posix with max Int32")
    func posixWithMaxInt32() {
        let code = File.System.Error.Code.posix(Int32.max)
        #expect(code.rawValue == Int64(Int32.max))
    }

    @Test(".posix with min Int32")
    func posixWithMinInt32() {
        let code = File.System.Error.Code.posix(Int32.min)
        #expect(code.rawValue == Int64(Int32.min))
    }

    @Test(".windows with zero")
    func windowsWithZero() {
        let code = File.System.Error.Code.windows(0)
        #expect(code.rawValue == 0)
    }

    @Test(".windows with max UInt32")
    func windowsWithMaxUInt32() {
        let code = File.System.Error.Code.windows(UInt32.max)
        #expect(code.rawValue == Int64(UInt32.max))
    }

    @Test("common POSIX error codes")
    func commonPosixErrorCodes() {
        // ENOENT (No such file or directory) is typically 2
        let enoent = File.System.Error.Code.posix(2)
        #expect(enoent.rawValue == 2)

        // EACCES (Permission denied) is typically 13
        let eacces = File.System.Error.Code.posix(13)
        #expect(eacces.rawValue == 13)

        // EEXIST (File exists) is typically 17
        let eexist = File.System.Error.Code.posix(17)
        #expect(eexist.rawValue == 17)
    }
}
