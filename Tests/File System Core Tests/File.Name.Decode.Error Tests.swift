//
//  File.Name.Decode.Error Tests.swift
//  swift-file-system
//

import ASCII
import Kernel
import Testing

@testable import File_System_Core

extension File.Name.Decode.Error {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)

    // MARK: - Unit Tests

    extension File.Name.Decode.Error.Test.Unit {

        // MARK: - Initialization

        @Test
        func `init stores the undecodable name`() {
            let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
            let error = File.Name.Decode.Error(name: name)
            #expect(error.name == name)
        }

        // MARK: - Error Conformance

        @Test
        func `Decode.Error conforms to Swift.Error`() {
            let name = File.Name(rawBytes: [0x80])
            let error: any Swift.Error = File.Name.Decode.Error(name: name)
            #expect(error is File.Name.Decode.Error)
        }

        @Test
        func `Decode.Error can be thrown and caught`() {
            let name = File.Name(rawBytes: [0x80])

            do {
                throw File.Name.Decode.Error(name: name)
            } catch let error as File.Name.Decode.Error {
                #expect(error.name == name)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        // MARK: - Equatable

        @Test
        func `Decode.Error is Equatable - same name`() {
            let name = File.Name(rawBytes: [0x80, 0x81])
            let error1 = File.Name.Decode.Error(name: name)
            let error2 = File.Name.Decode.Error(name: name)
            #expect(error1 == error2)
        }

        @Test
        func `Decode.Error is Equatable - different names`() {
            let name1 = File.Name(rawBytes: [0x80])
            let name2 = File.Name(rawBytes: [0x81])
            let error1 = File.Name.Decode.Error(name: name1)
            let error2 = File.Name.Decode.Error(name: name2)
            #expect(error1 != error2)
        }

        // MARK: - Sendable

        @Test
        func `Decode.Error is Sendable`() async {
            let name = File.Name(rawBytes: [0x80])
            let error = File.Name.Decode.Error(name: name)

            let result = await Task {
                error.name
            }.value

            #expect(result == name)
        }

        // MARK: - CustomStringConvertible

        @Test
        func `description includes debug description of name`() {
            let name = File.Name(rawBytes: [0x80, 0x81])
            let error = File.Name.Decode.Error(name: name)

            #expect(error.description.contains("File.Name.Decode.Error"))
        }

        @Test
        func `description for valid UTF-8 name shows name`() {
            // This case shouldn't happen in practice (why throw for valid UTF-8?)
            // but the error should still work correctly
            let name = File.Name(rawBytes: Array("valid".utf8))
            let error = File.Name.Decode.Error(name: name)

            #expect(error.description.contains("File.Name.Decode.Error"))
            #expect(error.description.contains("valid"))
        }

        // MARK: - debugRawBytes

        @Test
        func `debugRawBytes returns hex-encoded bytes`() {
            let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
            let error = File.Name.Decode.Error(name: name)

            let hex = error.debugRawBytes
            // Hex encoding of [0x80, 0x81, 0x82]
            #expect(hex.contains("80"))
            #expect(hex.contains("81"))
            #expect(hex.contains("82"))
        }

        @Test
        func `debugRawBytes is uppercase`() {
            let name = File.Name(rawBytes: [0xAB, 0xCD])
            let error = File.Name.Decode.Error(name: name)

            let hex = error.debugRawBytes
            #expect(hex.contains("AB"))
            #expect(hex.contains("CD"))
        }

        @Test
        func `debugRawBytes for valid ASCII shows hex`() {
            let name = File.Name(rawBytes: [0x41, 0x42])  // "AB"
            let error = File.Name.Decode.Error(name: name)

            let hex = error.debugRawBytes
            #expect(hex.contains("41"))
            #expect(hex.contains("42"))
        }

        @Test
        func `debugRawBytes for empty name returns empty string`() {
            let name = File.Name(rawBytes: [])
            let error = File.Name.Decode.Error(name: name)

            let hex = error.debugRawBytes
            #expect(hex.isEmpty)
        }
    }

    // MARK: - Edge Cases

    extension File.Name.Decode.Error.Test.EdgeCase {

        @Test
        func `error with single invalid byte`() {
            let name = File.Name(rawBytes: [0xFF])
            let error = File.Name.Decode.Error(name: name)

            #expect(error.debugRawBytes == "FF")
        }

        @Test
        func `error with long sequence of invalid bytes`() {
            let bytes: [UInt8] = Array(repeating: 0x80, count: 100)
            let name = File.Name(rawBytes: bytes)
            let error = File.Name.Decode.Error(name: name)

            let hex = error.debugRawBytes
            // 100 bytes * 2 hex chars = 200 characters
            #expect(hex.count == 200)
        }

        @Test
        func `error preserves exact byte sequence`() {
            let bytes: [UInt8] = [0x00, 0x7F, 0x80, 0xFF]
            let name = File.Name(rawBytes: bytes)
            let error = File.Name.Decode.Error(name: name)

            #expect(error.name == name)
            #expect(error.debugRawBytes.contains("00"))
            #expect(error.debugRawBytes.contains("7F"))
            #expect(error.debugRawBytes.contains("80"))
            #expect(error.debugRawBytes.contains("FF"))
        }

        @Test
        func `error can be used in Result type`() {
            let name = File.Name(rawBytes: [0x80])
            let result: Result<Swift.String, File.Name.Decode.Error> = .failure(
                File.Name.Decode.Error(name: name)
            )

            switch result {
            case .success:
                Issue.record("Expected failure")

            case .failure(let error):
                #expect(error.name == name)
            }
        }

        @Test
        func `error can be boxed in existential`() {
            let name = File.Name(rawBytes: [0x80])
            let error: any Swift.Error = File.Name.Decode.Error(name: name)

            if let decodeError = error as? File.Name.Decode.Error {
                #expect(decodeError.name == name)
            } else {
                Issue.record("Failed to cast to Decode.Error")
            }
        }
    }
#endif
