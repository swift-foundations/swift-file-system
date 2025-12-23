//
//  File.Name Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Name {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Name.Test.Unit {

    // MARK: - Semantic Predicates

    @Test("isHiddenByDotPrefix returns true for dot-prefixed names")
    func hiddenByDotPrefixTrue() {
        let hidden = File.Name(rawBytes: [UInt8].ascii.unchecked(".hidden"))
        #expect(hidden.isHiddenByDotPrefix)
    }

    @Test("isHiddenByDotPrefix returns false for regular names")
    func hiddenByDotPrefixFalse() {
        let visible = File.Name(rawBytes: [UInt8].ascii.unchecked("visible.txt"))
        #expect(!visible.isHiddenByDotPrefix)
    }

    @Test("isHiddenByDotPrefix returns true for dotfiles")
    func hiddenByDotPrefixDotfiles() {
        let gitignore = File.Name(rawBytes: [UInt8].ascii.unchecked(".gitignore"))
        let bashrc = File.Name(rawBytes: [UInt8].ascii.unchecked(".bashrc"))
        let dsstore = File.Name(rawBytes: [UInt8].ascii.unchecked(".DS_Store"))

        #expect(gitignore.isHiddenByDotPrefix)
        #expect(bashrc.isHiddenByDotPrefix)
        #expect(dsstore.isHiddenByDotPrefix)
    }

    // MARK: - String Conversion (Strict)

    @Test("String(fileName) succeeds for valid ASCII")
    func stringConversionValidASCII() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("hello.txt"))
        let str = String(name)
        #expect(str == "hello.txt")
    }

    @Test("String(fileName) succeeds for valid UTF-8")
    func stringConversionValidUTF8() {
        let name = File.Name(rawBytes: Array("日本語.txt".utf8))
        let str = String(name)
        #expect(str == "日本語.txt")
    }

    @Test("String(fileName) returns nil for invalid UTF-8")
    func stringConversionInvalidUTF8() {
        // Invalid UTF-8: 0x80 is a continuation byte without a leading byte
        let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
        let str = String(name)
        #expect(str == nil)
    }

    @Test("String(fileName) returns nil for invalid UTF-8 sequence in middle")
    func stringConversionInvalidMiddle() {
        // "hello" + invalid byte + "world"
        var bytes = [UInt8].ascii.unchecked("hello")
        bytes.append(0xFF)  // Invalid UTF-8 byte
        bytes.append(contentsOf: [UInt8].ascii.unchecked("world"))

        let name = File.Name(rawBytes: bytes)
        #expect(String(name) == nil)
    }

    // MARK: - String Conversion (Lossy)

    @Test("String(lossy:) succeeds for valid UTF-8")
    func stringLossyValidUTF8() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("hello.txt"))
        let str = String(lossy: name)
        #expect(str == "hello.txt")
    }

    @Test("String(lossy:) replaces invalid bytes with replacement character")
    func stringLossyReplacesInvalid() {
        // Invalid UTF-8: 0x80 is a continuation byte
        let name = File.Name(rawBytes: [0x80])
        let str = String(lossy: name)
        #expect(str == "\u{FFFD}")  // Unicode replacement character
    }

    @Test("String(lossy:) replaces multiple invalid bytes")
    func stringLossyReplacesMultiple() {
        // "A" + invalid + "B" + invalid + "C"
        let name = File.Name(rawBytes: [0x41, 0x80, 0x42, 0xFF, 0x43])
        let str = String(lossy: name)
        // Each invalid byte becomes a replacement character
        #expect(str.contains("\u{FFFD}"))
        #expect(str.contains("A"))
        #expect(str.contains("B"))
        #expect(str.contains("C"))
    }

    // MARK: - String Conversion (Validating)

    @Test("String(validating:) succeeds for valid UTF-8")
    func stringValidatingValid() throws {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("valid.txt"))
        let str = try String(validating: name)
        #expect(str == "valid.txt")
    }

    @Test("String(validating:) throws Decode.Error for invalid UTF-8")
    func stringValidatingThrows() throws {
        let name = File.Name(rawBytes: [0x80, 0x81])

        #expect(throws: File.Name.Decode.Error.self) {
            _ = try String(validating: name)
        }
    }

    @Test("String(validating:) thrown error contains the name")
    func stringValidatingErrorContainsName() {
        let name = File.Name(rawBytes: [0x80, 0x81])

        #expect(throws: File.Name.Decode.Error.self) {
            _ = try String(validating: name)
        }
    }

    // MARK: - Equatable

    @Test("File.Name is Equatable - same bytes are equal")
    func equatableSameBytes() {
        let name1 = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        let name2 = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        #expect(name1 == name2)
    }

    @Test("File.Name is Equatable - different bytes are not equal")
    func equatableDifferentBytes() {
        let name1 = File.Name(rawBytes: [UInt8].ascii.unchecked("file1.txt"))
        let name2 = File.Name(rawBytes: [UInt8].ascii.unchecked("file2.txt"))
        #expect(name1 != name2)
    }

    @Test("File.Name equality is case-sensitive")
    func equatableCaseSensitive() {
        let lower = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        let upper = File.Name(rawBytes: [UInt8].ascii.unchecked("FILE.TXT"))
        #expect(lower != upper)
    }

    // MARK: - Hashable

    @Test("File.Name is Hashable - same bytes have same hash")
    func hashableSameHash() {
        let name1 = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        let name2 = File.Name(rawBytes: [UInt8].ascii.unchecked("file.txt"))
        #expect(name1.hashValue == name2.hashValue)
    }

    @Test("File.Name works in Set")
    func hashableInSet() {
        let name1 = File.Name(rawBytes: [UInt8].ascii.unchecked("file1.txt"))
        let name2 = File.Name(rawBytes: [UInt8].ascii.unchecked("file2.txt"))
        let name3 = File.Name(rawBytes: [UInt8].ascii.unchecked("file1.txt"))  // Duplicate

        let set: Set<File.Name> = [name1, name2, name3]
        #expect(set.count == 2)
    }

    @Test("File.Name works as Dictionary key")
    func hashableAsDictionaryKey() {
        let name1 = File.Name(rawBytes: [UInt8].ascii.unchecked("key1"))
        let name2 = File.Name(rawBytes: [UInt8].ascii.unchecked("key2"))

        var dict: [File.Name: Int] = [:]
        dict[name1] = 1
        dict[name2] = 2

        #expect(dict[name1] == 1)
        #expect(dict[name2] == 2)
    }

    // MARK: - CustomStringConvertible

    @Test("description returns decoded string for valid UTF-8")
    func descriptionValidUTF8() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("document.pdf"))
        #expect(name.description == "document.pdf")
    }

    @Test("description returns lossy decoded string for invalid UTF-8")
    func descriptionInvalidUTF8() {
        let name = File.Name(rawBytes: [0x80])
        // Should use lossy decoding, replacing invalid byte with replacement character
        #expect(name.description.contains("\u{FFFD}"))
    }

    // MARK: - CustomDebugStringConvertible

    @Test("debugDescription shows File.Name wrapper for valid UTF-8")
    func debugDescriptionValid() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("test.txt"))
        #expect(name.debugDescription == "File.Name(\"test.txt\")")
    }

    @Test("debugDescription shows hex for invalid UTF-8")
    func debugDescriptionInvalid() {
        let name = File.Name(rawBytes: [0x80, 0x81])
        // Should include hex representation
        #expect(name.debugDescription.contains("invalidUTF8"))
        #expect(name.debugDescription.contains("8081"))
    }

    // MARK: - Sendable

    @Test("File.Name is Sendable")
    func sendable() async {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("sendable.txt"))

        // Pass to async task to verify Sendable conformance
        let result = await Task {
            String(name)
        }.value

        #expect(result == "sendable.txt")
    }
}

// MARK: - Edge Cases

extension File.Name.Test.EdgeCase {

    @Test("empty name")
    func emptyName() {
        let name = File.Name(rawBytes: [])
        #expect(String(name).isEmpty)
        #expect(!name.isHiddenByDotPrefix)
    }

    @Test("single dot")
    func singleDot() {
        let name = File.Name(rawBytes: [0x2E])  // "."
        #expect(String(name) == ".")
        #expect(name.isHiddenByDotPrefix)
    }

    @Test("double dot")
    func doubleDot() {
        let name = File.Name(rawBytes: [0x2E, 0x2E])  // ".."
        #expect(String(name) == "..")
        #expect(name.isHiddenByDotPrefix)
    }

    @Test("Unicode filename - Japanese")
    func unicodeJapanese() {
        let name = File.Name(rawBytes: Array("日本語ファイル.txt".utf8))
        #expect(String(name) == "日本語ファイル.txt")
    }

    @Test("Unicode filename - emoji")
    func unicodeEmoji() {
        let name = File.Name(rawBytes: Array("📁folder📁.dir".utf8))
        #expect(String(name) == "📁folder📁.dir")
    }

    @Test("Unicode filename - mixed scripts")
    func unicodeMixedScripts() {
        let name = File.Name(rawBytes: Array("Привет_こんにちは_Hello.txt".utf8))
        #expect(String(name) == "Привет_こんにちは_Hello.txt")
    }

    @Test("name with spaces")
    func nameWithSpaces() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("my file name.txt"))
        #expect(String(name) == "my file name.txt")
        #expect(!name.isHiddenByDotPrefix)
    }

    @Test("name with special characters")
    func nameWithSpecialCharacters() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked("file@#$%^&()_+-=.txt"))
        #expect(String(name) == "file@#$%^&()_+-=.txt")
    }

    @Test("name with leading space")
    func nameWithLeadingSpace() {
        let name = File.Name(rawBytes: [UInt8].ascii.unchecked(" leadingspace.txt"))
        #expect(String(name) == " leadingspace.txt")
        #expect(!name.isHiddenByDotPrefix)  // Space, not dot
    }

    @Test("invalid UTF-8: lone continuation byte")
    func invalidLoneContinuationByte() {
        // 0x80-0xBF are continuation bytes
        let name = File.Name(rawBytes: [0x80])
        #expect(String(name) == nil)
        #expect(String(lossy: name) == "\u{FFFD}")
    }

    @Test("invalid UTF-8: incomplete multibyte sequence")
    func invalidIncompleteMultibyte() {
        // 0xC0-0xDF expect 1 continuation byte
        let name = File.Name(rawBytes: [0xC0])  // Missing continuation
        #expect(String(name) == nil)
    }

    @Test("invalid UTF-8: overlong encoding")
    func invalidOverlongEncoding() {
        // Overlong encoding of '/' (should be 0x2F)
        // 0xC0 0xAF is an overlong encoding - rejected by strict UTF-8
        let name = File.Name(rawBytes: [0xC0, 0xAF])
        #expect(String(name) == nil)
    }

    @Test("invalid UTF-8: 0xFF byte")
    func invalidFFByte() {
        // 0xFF is never valid in UTF-8
        let name = File.Name(rawBytes: [0xFF])
        #expect(String(name) == nil)
    }

    @Test("invalid UTF-8: truncated 4-byte sequence")
    func invalidTruncatedFourByte() {
        // 0xF0 starts a 4-byte sequence but we only provide 2 bytes
        let name = File.Name(rawBytes: [0xF0, 0x90])
        #expect(String(name) == nil)
    }

    @Test("very long filename")
    func veryLongFilename() {
        // Create a 255-character filename (common filesystem limit)
        let longName = String(repeating: "a", count: 255)
        let name = File.Name(rawBytes: Array(longName.utf8))
        #expect(String(name) == longName)
    }

    @Test("filename with null byte")
    func filenameWithNullByte() {
        // Null byte in the middle - still valid UTF-8, but unusual
        let name = File.Name(rawBytes: [0x61, 0x00, 0x62])  // "a\0b"
        let str = String(name)
        #expect(str != nil)
        #expect(str?.count == 3)
    }

    @Test("filename with all ASCII control characters")
    func filenameWithControlCharacters() {
        // Tab and other control characters - valid UTF-8
        let name = File.Name(rawBytes: [0x09, 0x0A, 0x0D])  // tab, newline, carriage return
        let str = String(name)
        #expect(str != nil)
    }
}
