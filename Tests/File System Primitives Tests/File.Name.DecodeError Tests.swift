//
//  File.Name.DecodeError Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Name.DecodeError {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Name.DecodeError.Test.Unit {

    // MARK: - Initialization

    @Test("init stores the undecodable name")
    func initStoresName() {
        let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
        let error = File.Name.DecodeError(name: name)
        #expect(error.name == name)
    }

    // MARK: - Error Conformance

    @Test("DecodeError conforms to Swift.Error")
    func conformsToError() {
        let name = File.Name(rawBytes: [0x80])
        let error: any Swift.Error = File.Name.DecodeError(name: name)
        #expect(error is File.Name.DecodeError)
    }

    @Test("DecodeError can be thrown and caught")
    func canBeThrownAndCaught() {
        let name = File.Name(rawBytes: [0x80])

        do {
            throw File.Name.DecodeError(name: name)
        } catch let error as File.Name.DecodeError {
            #expect(error.name == name)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Equatable

    @Test("DecodeError is Equatable - same name")
    func equatableSameName() {
        let name = File.Name(rawBytes: [0x80, 0x81])
        let error1 = File.Name.DecodeError(name: name)
        let error2 = File.Name.DecodeError(name: name)
        #expect(error1 == error2)
    }

    @Test("DecodeError is Equatable - different names")
    func equatableDifferentNames() {
        let name1 = File.Name(rawBytes: [0x80])
        let name2 = File.Name(rawBytes: [0x81])
        let error1 = File.Name.DecodeError(name: name1)
        let error2 = File.Name.DecodeError(name: name2)
        #expect(error1 != error2)
    }

    // MARK: - Sendable

    @Test("DecodeError is Sendable")
    func sendable() async {
        let name = File.Name(rawBytes: [0x80])
        let error = File.Name.DecodeError(name: name)

        let result = await Task {
            error.name
        }.value

        #expect(result == name)
    }

    // MARK: - CustomStringConvertible

    @Test("description includes debug description of name")
    func descriptionIncludesNameDebug() {
        let name = File.Name(rawBytes: [0x80, 0x81])
        let error = File.Name.DecodeError(name: name)

        #expect(error.description.contains("File.Name.DecodeError"))
        #expect(error.description.contains("invalidUTF8"))
    }

    @Test("description for valid UTF-8 name shows name")
    func descriptionValidUTF8() {
        // This case shouldn't happen in practice (why throw for valid UTF-8?)
        // but the error should still work correctly
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("valid"))
        let error = File.Name.DecodeError(name: name)

        #expect(error.description.contains("File.Name.DecodeError"))
        #expect(error.description.contains("valid"))
    }

    // MARK: - debugRawBytes

    @Test("debugRawBytes returns hex-encoded bytes")
    func debugRawBytesHexEncoded() {
        let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
        let error = File.Name.DecodeError(name: name)

        let hex = error.debugRawBytes
        // Hex encoding of [0x80, 0x81, 0x82]
        #expect(hex.contains("80"))
        #expect(hex.contains("81"))
        #expect(hex.contains("82"))
    }

    @Test("debugRawBytes is uppercase")
    func debugRawBytesUppercase() {
        let name = File.Name(rawBytes: [0xAB, 0xCD])
        let error = File.Name.DecodeError(name: name)

        let hex = error.debugRawBytes
        #expect(hex.contains("AB"))
        #expect(hex.contains("CD"))
    }

    @Test("debugRawBytes for valid ASCII shows hex")
    func debugRawBytesValidASCII() {
        let name = File.Name(rawBytes: [0x41, 0x42])  // "AB"
        let error = File.Name.DecodeError(name: name)

        let hex = error.debugRawBytes
        #expect(hex.contains("41"))
        #expect(hex.contains("42"))
    }

    @Test("debugRawBytes for empty name returns empty string")
    func debugRawBytesEmpty() {
        let name = File.Name(rawBytes: [])
        let error = File.Name.DecodeError(name: name)

        let hex = error.debugRawBytes
        #expect(hex.isEmpty)
    }
}

// MARK: - Edge Cases

extension File.Name.DecodeError.Test.EdgeCase {

    @Test("error with single invalid byte")
    func singleInvalidByte() {
        let name = File.Name(rawBytes: [0xFF])
        let error = File.Name.DecodeError(name: name)

        #expect(error.debugRawBytes == "FF")
    }

    @Test("error with long sequence of invalid bytes")
    func longInvalidSequence() {
        let bytes: [UInt8] = Array(repeating: 0x80, count: 100)
        let name = File.Name(rawBytes: bytes)
        let error = File.Name.DecodeError(name: name)

        let hex = error.debugRawBytes
        // 100 bytes * 2 hex chars = 200 characters
        #expect(hex.count == 200)
    }

    @Test("error preserves exact byte sequence")
    func preservesExactBytes() {
        let bytes: [UInt8] = [0x00, 0x7F, 0x80, 0xFF]
        let name = File.Name(rawBytes: bytes)
        let error = File.Name.DecodeError(name: name)

        #expect(error.name == name)
        #expect(error.debugRawBytes.contains("00"))
        #expect(error.debugRawBytes.contains("7F"))
        #expect(error.debugRawBytes.contains("80"))
        #expect(error.debugRawBytes.contains("FF"))
    }

    @Test("error can be used in Result type")
    func usableInResult() {
        let name = File.Name(rawBytes: [0x80])
        let result: Result<String, File.Name.DecodeError> = .failure(File.Name.DecodeError(name: name))

        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure(let error):
            #expect(error.name == name)
        }
    }

    @Test("error can be boxed in existential")
    func boxedInExistential() {
        let name = File.Name(rawBytes: [0x80])
        let error: any Error = File.Name.DecodeError(name: name)

        if let decodeError = error as? File.Name.DecodeError {
            #expect(decodeError.name == name)
        } else {
            Issue.record("Failed to cast to DecodeError")
        }
    }
}
