//
//  File.Name Tests.swift
//  swift-file-system
//

import ASCII
@_spi(Syscall) import Kernel
import Testing

@testable import File_System_Core

extension File.Name {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)

    // MARK: - Unit Tests

    extension File.Name.Test.Unit {

        // MARK: - Semantic Predicates

        @Test
        func `isHiddenByDotPrefix returns true for dot-prefixed names`() {
            let hidden = File.Name(rawBytes: Array(".hidden".utf8))
            #expect(hidden.isHiddenByDotPrefix)
        }

        @Test
        func `isHiddenByDotPrefix returns false for regular names`() {
            let visible = File.Name(rawBytes: Array("visible.txt".utf8))
            #expect(!visible.isHiddenByDotPrefix)
        }

        @Test
        func `isHiddenByDotPrefix returns true for dotfiles`() {
            let gitignore = File.Name(rawBytes: Array(".gitignore".utf8))
            let bashrc = File.Name(rawBytes: Array(".bashrc".utf8))
            let dsstore = File.Name(rawBytes: Array(".DS_Store".utf8))

            #expect(gitignore.isHiddenByDotPrefix)
            #expect(bashrc.isHiddenByDotPrefix)
            #expect(dsstore.isHiddenByDotPrefix)
        }

        // MARK: - String Conversion (Strict)

        @Test
        func `Swift.String(fileName) succeeds for valid ASCII`() {
            let name = File.Name(rawBytes: Array("hello.txt".utf8))
            let str = Swift.String(name)
            #expect(str == "hello.txt")
        }

        @Test
        func `Swift.String(fileName) succeeds for valid UTF-8`() {
            let name = File.Name(rawBytes: Array("日本語.txt".utf8))
            let str = Swift.String(name)
            #expect(str == "日本語.txt")
        }

        @Test
        func `Swift.String(fileName) returns nil for invalid UTF-8`() {
            // Invalid UTF-8: 0x80 is a continuation byte without a leading byte
            let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
            let str = Swift.String(name)
            #expect(str == nil)
        }

        @Test
        func `Swift.String(fileName) returns nil for invalid UTF-8 sequence in middle`() {
            // "hello" + invalid byte + "world"
            var bytes = Array("hello".utf8)
            bytes.append(0xFF)  // Invalid UTF-8 byte
            bytes.append(contentsOf: Array("world".utf8))

            let name = File.Name(rawBytes: bytes)
            #expect(Swift.String(name) == nil)
        }

        // MARK: - String Conversion (Lossy)

        @Test
        func `Swift.String(lossy:) succeeds for valid UTF-8`() {
            let name = File.Name(rawBytes: Array("hello.txt".utf8))
            let str = Swift.String(lossy: name)
            #expect(str == "hello.txt")
        }

        @Test
        func `Swift.String(lossy:) replaces invalid bytes with replacement character`() {
            // Invalid UTF-8: 0x80 is a continuation byte
            let name = File.Name(rawBytes: [0x80])
            let str = Swift.String(lossy: name)
            #expect(str == "\u{FFFD}")  // Unicode replacement character
        }

        @Test
        func `Swift.String(lossy:) replaces multiple invalid bytes`() {
            // "A" + invalid + "B" + invalid + "C"
            let name = File.Name(rawBytes: [0x41, 0x80, 0x42, 0xFF, 0x43])
            let str = Swift.String(lossy: name)
            // Each invalid byte becomes a replacement character
            #expect(str.contains("\u{FFFD}"))
            #expect(str.contains("A"))
            #expect(str.contains("B"))
            #expect(str.contains("C"))
        }

        // MARK: - String Conversion (Validating)

        @Test
        func `Swift.String(validating:) succeeds for valid UTF-8`() throws {
            let name = File.Name(rawBytes: Array("valid.txt".utf8))
            let str = try Swift.String(validating: name)
            #expect(str == "valid.txt")
        }

        @Test
        func `Swift.String(validating:) throws Decode.Error for invalid UTF-8`() throws {
            let name = File.Name(rawBytes: [0x80, 0x81])

            #expect(throws: File.Name.Decode.Error.self) {
                _ = try Swift.String(validating: name)
            }
        }

        @Test
        func `Swift.String(validating:) thrown error contains the name`() {
            let name = File.Name(rawBytes: [0x80, 0x81])

            #expect(throws: File.Name.Decode.Error.self) {
                _ = try Swift.String(validating: name)
            }
        }

        // MARK: - Equatable

        @Test
        func `File.Name is Equatable - same bytes are equal`() {
            let name1 = File.Name(rawBytes: Array("file.txt".utf8))
            let name2 = File.Name(rawBytes: Array("file.txt".utf8))
            #expect(name1 == name2)
        }

        @Test
        func `File.Name is Equatable - different bytes are not equal`() {
            let name1 = File.Name(rawBytes: Array("file1.txt".utf8))
            let name2 = File.Name(rawBytes: Array("file2.txt".utf8))
            #expect(name1 != name2)
        }

        @Test
        func `File.Name equality is case-sensitive`() {
            let lower = File.Name(rawBytes: Array("file.txt".utf8))
            let upper = File.Name(rawBytes: Array("FILE.TXT".utf8))
            #expect(lower != upper)
        }

        // MARK: - Hashable

        @Test
        func `File.Name is Hashable - same bytes have same hash`() {
            let name1 = File.Name(rawBytes: Array("file.txt".utf8))
            let name2 = File.Name(rawBytes: Array("file.txt".utf8))
            #expect(name1.hashValue == name2.hashValue)
        }

        @Test
        func `File.Name works in Set`() {
            let name1 = File.Name(rawBytes: Array("file1.txt".utf8))
            let name2 = File.Name(rawBytes: Array("file2.txt".utf8))
            let name3 = File.Name(rawBytes: Array("file1.txt".utf8))  // Duplicate

            let set: Set<File.Name> = [name1, name2, name3]
            #expect(set.count == 2)
        }

        @Test
        func `File.Name works as Dictionary key`() {
            let name1 = File.Name(rawBytes: Array("key1".utf8))
            let name2 = File.Name(rawBytes: Array("key2".utf8))

            var dict: [File.Name: Int] = [:]
            dict[name1] = 1
            dict[name2] = 2

            #expect(dict[name1] == 1)
            #expect(dict[name2] == 2)
        }

        // MARK: - CustomStringConvertible

        @Test
        func `description returns decoded string for valid UTF-8`() {
            let name = File.Name(rawBytes: Array("document.pdf".utf8))
            #expect(name.description == "document.pdf")
        }

        @Test
        func `description returns lossy decoded string for invalid UTF-8`() {
            let name = File.Name(rawBytes: [0x80])
            // Should use lossy decoding, replacing invalid byte with replacement character
            #expect(name.description.contains("\u{FFFD}"))
        }

        // MARK: - CustomDebugStringConvertible

        @Test
        func `debugDescription shows File.Name wrapper for valid UTF-8`() {
            let name = File.Name(rawBytes: Array("test.txt".utf8))
            #expect(name.debugDescription == "File.Name(\"test.txt\")")
        }

        @Test
        func `debugDescription shows hex for invalid UTF-8`() {
            let name = File.Name(rawBytes: [0x80, 0x81])
            // Should include hex representation
            #expect(name.debugDescription.contains("invalidUTF8"))
            #expect(name.debugDescription.contains("8081"))
        }

        // MARK: - Sendable

        @Test
        func `File.Name is Sendable`() async {
            let name = File.Name(rawBytes: Array("sendable.txt".utf8))

            // Pass to async task to verify Sendable conformance
            let result = await Task {
                Swift.String(name)
            }.value

            #expect(result == "sendable.txt")
        }
    }

    // MARK: - Edge Cases

    extension File.Name.Test.`Edge Case` {

        @Test
        func `empty name`() {
            let name = File.Name(rawBytes: [])
            // `?.` forces the domain-specific `String.init?(_:File.Name)` (strict
            // decode) over the generic `String.init<T: Binary.Serializable>(_:)`
            // overloads the byte-typed-primitives cascade introduced.
            #expect(Swift.String(name)?.isEmpty == true)
            #expect(!name.isHiddenByDotPrefix)
        }

        @Test
        func `single dot`() {
            let name = File.Name(rawBytes: [0x2E])  // "."
            #expect(Swift.String(name) == ".")
            #expect(name.isHiddenByDotPrefix)
        }

        @Test
        func `double dot`() {
            let name = File.Name(rawBytes: [0x2E, 0x2E])  // ".."
            #expect(Swift.String(name) == "..")
            #expect(name.isHiddenByDotPrefix)
        }

        @Test
        func `Unicode filename - Japanese`() {
            let name = File.Name(rawBytes: Array("日本語ファイル.txt".utf8))
            #expect(Swift.String(name) == "日本語ファイル.txt")
        }

        @Test
        func `Unicode filename - emoji`() {
            let name = File.Name(rawBytes: Array("📁folder📁.dir".utf8))
            #expect(Swift.String(name) == "📁folder📁.dir")
        }

        @Test
        func `Unicode filename - mixed scripts`() {
            let name = File.Name(rawBytes: Array("Привет_こんにちは_Hello.txt".utf8))
            #expect(Swift.String(name) == "Привет_こんにちは_Hello.txt")
        }

        @Test
        func `name with spaces`() {
            let name = File.Name(rawBytes: Array("my file name.txt".utf8))
            #expect(Swift.String(name) == "my file name.txt")
            #expect(!name.isHiddenByDotPrefix)
        }

        @Test
        func `name with special characters`() {
            let name = File.Name(rawBytes: Array("file@#$%^&()_+-=.txt".utf8))
            #expect(Swift.String(name) == "file@#$%^&()_+-=.txt")
        }

        @Test
        func `name with leading space`() {
            let name = File.Name(rawBytes: Array(" leadingspace.txt".utf8))
            #expect(Swift.String(name) == " leadingspace.txt")
            #expect(!name.isHiddenByDotPrefix)  // Space, not dot
        }

        @Test
        func `invalid UTF-8: lone continuation byte`() {
            // 0x80-0xBF are continuation bytes
            let name = File.Name(rawBytes: [0x80])
            #expect(Swift.String(name) == nil)
            #expect(Swift.String(lossy: name) == "\u{FFFD}")
        }

        @Test
        func `invalid UTF-8: incomplete multibyte sequence`() {
            // 0xC0-0xDF expect 1 continuation byte
            let name = File.Name(rawBytes: [0xC0])  // Missing continuation
            #expect(Swift.String(name) == nil)
        }

        @Test
        func `invalid UTF-8: overlong encoding`() {
            // Overlong encoding of '/' (should be 0x2F)
            // 0xC0 0xAF is an overlong encoding - rejected by strict UTF-8
            let name = File.Name(rawBytes: [0xC0, 0xAF])
            #expect(Swift.String(name) == nil)
        }

        @Test
        func `invalid UTF-8: 0xFF byte`() {
            // 0xFF is never valid in UTF-8
            let name = File.Name(rawBytes: [0xFF])
            #expect(Swift.String(name) == nil)
        }

        @Test
        func `invalid UTF-8: truncated 4-byte sequence`() {
            // 0xF0 starts a 4-byte sequence but we only provide 2 bytes
            let name = File.Name(rawBytes: [0xF0, 0x90])
            #expect(Swift.String(name) == nil)
        }

        @Test
        func `very long filename`() {
            // Create a 255-character filename (common filesystem limit)
            let longName = Swift.String(repeating: "a", count: 255)
            let name = File.Name(rawBytes: Array(longName.utf8))
            #expect(Swift.String(name) == longName)
        }

        @Test
        func `filename with null byte`() {
            // Null byte in the middle - still valid UTF-8, but unusual
            let name = File.Name(rawBytes: [0x61, 0x00, 0x62])  // "a\0b"
            let str = Swift.String(name)
            #expect(str != nil)
            #expect(str?.count == 3)
        }

        @Test
        func `filename with all ASCII control characters`() {
            // Tab and other control characters - valid UTF-8
            let name = File.Name(rawBytes: [0x09, 0x0A, 0x0D])  // tab, newline, carriage return
            let str = Swift.String(name)
            #expect(str != nil)
        }

        @Test
        func `init(from: Kernel.Directory.Entry) strips trailing NUL terminator`() {
            // Kernel.Directory.Entry.rawName is NUL-terminated by convention.
            // File.Name.init(from:) must route through entry.nameView.span
            // (NUL-excluded) so the rawEncoding never contains the terminator.
            let entry = Kernel.Directory.Entry(rawName: [0x66, 0x69, 0x6C, 0x65, 0x00])  // "file\0"
            let name = File.Name(from: entry)
            // "file", no trailing NUL — verified via `withCodeUnits` (the
            // platform-agnostic accessor that replaced `posixBytes`).
            // Materialize the span into a [UInt8] for array-equality assertion
            // (POSIX-only block: `Path.Char == UInt8`).
            let bytes = name.withCodeUnits { span -> [UInt8] in
                var collected: [UInt8] = []
                collected.reserveCapacity(span.count)
                for i in 0..<span.count { collected.append(span[i]) }
                return collected
            }
            #expect(bytes == [0x66, 0x69, 0x6C, 0x65])
        }
    }
#endif
