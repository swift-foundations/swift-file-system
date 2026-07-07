//
//  File.Directory.Entry Tests.swift
//  swift-file-system
//

import ASCII
import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Entry {
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

    extension File.Directory.Entry.Test.Unit {
        @Test
        func `init with all properties`() throws {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("testfile.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(Swift.String(entry.name) == "testfile.txt")
            #expect(try entry.path() == "/tmp/testfile.txt")
            #expect(entry.type == .file)
        }

        @Test
        func `init with directory type`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("mydir".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .directory
            )

            #expect(Swift.String(entry.name) == "mydir")
            #expect(entry.type == .directory)
        }

        @Test
        func `init with symbolic link type`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("mylink".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .symbolicLink
            )

            #expect(Swift.String(entry.name) == "mylink")
            #expect(entry.type == .symbolicLink)
        }

        @Test
        func `init with other type`() {
            let parent: File.Path = "/dev"
            let name = File.Name(rawBytes: Array("null".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .other
            )

            #expect(Swift.String(entry.name) == "null")
            #expect(entry.type == .other)
        }

        @Test
        func `path is computed from parent and name`() throws {
            let parent: File.Path = "/usr/local/bin"
            let name = File.Name(rawBytes: Array("test".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(Swift.String(entry.name) == "test")
            #expect(try entry.path() == "/usr/local/bin/test")
        }

        @Test
        func `pathIfValid returns path for valid entry`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("valid.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(entry.pathIfValid != nil)
            #expect(entry.pathIfValid == "/tmp/valid.txt")
        }

        @Test
        func `parent is accessible`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("file.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(entry.parent == parent)
        }
    }

    // MARK: - Edge Cases

    extension File.Directory.Entry.Test.`Edge Case` {
        @Test
        func `entry with name containing spaces`() throws {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("my file.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(Swift.String(entry.name) == "my file.txt")
            #expect(try entry.path() == "/tmp/my file.txt")
        }

        @Test
        func `entry with unicode name`() throws {
            let parent: File.Path = "/tmp"
            // Use UTF-8 bytes directly for non-ASCII names
            let name = File.Name(rawBytes: Array("日本語ファイル.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(Swift.String(entry.name) == "日本語ファイル.txt")
            #expect(try entry.path() == "/tmp/日本語ファイル.txt")
        }

        @Test
        func `entry with hidden file name`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array(".hidden".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            #expect(Swift.String(entry.name) == ".hidden")
            #expect(entry.name.isHiddenByDotPrefix)
        }

        @Test
        func `Entry is Sendable`() async {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: Array("file.txt".utf8))
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            let result = await Task {
                (entry.name, entry.pathIfValid, entry.type)
            }.value

            // Annotate `String?` to select the domain-specific
            // `String.init?(_:File.Name)` (strict decode) over the generic
            // `String.init<T: Binary.Serializable>(_:)` overloads that the
            // byte-typed-primitives cascade introduced via ASCII / Binary
            // Serializable Primitives.
            let decodedName: Swift.String? = Swift.String(result.0)
            #expect(decodedName == "file.txt")
            #expect(result.1.map(Swift.String.init) == "/tmp/file.txt")
            #expect(result.2 == .file)
        }

        @Test
        func `Entry with undecodable name`() {
            let parent: File.Path = "/tmp"
            let name = File.Name(rawBytes: [0x80, 0x81, 0x82])  // Invalid UTF-8
            let entry = File.Directory.Entry(
                name: name,
                parent: parent,
                type: .file
            )

            // Name cannot be decoded to String
            #expect(Swift.String(entry.name) == nil)
            // But lossy decoding works
            #expect(Swift.String(lossy: entry.name).contains("\u{FFFD}"))
            // pathIfValid is nil for undecodable names
            #expect(entry.pathIfValid == nil)
            // path() throws for undecodable names
            #expect(throws: File.Path.Component.Error.self) {
                _ = try entry.path()
            }
            // Parent is still accessible
            #expect(entry.parent == parent)
        }

        @Test
        func `Entry stored in collection`() {
            let parent: File.Path = "/tmp"

            let entries: [File.Directory.Entry] = [
                File.Directory.Entry(
                    name: File.Name(rawBytes: Array("file1.txt".utf8)),
                    parent: parent,
                    type: .file
                ),
                File.Directory.Entry(
                    name: File.Name(rawBytes: Array("dir".utf8)),
                    parent: parent,
                    type: .directory
                ),
                File.Directory.Entry(
                    name: File.Name(rawBytes: [0x80]),
                    parent: parent,
                    type: .file
                ),
            ]

            #expect(entries.count == 3)

            let filesCount = entries.filter { $0.type == .file }.count
            #expect(filesCount == 2)

            let withPath = entries.compactMap { $0.pathIfValid }
            #expect(withPath.count == 2)
        }
    }
#endif
