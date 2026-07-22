// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing

@testable import File_System_Core

extension File.Path.Temporary {
    @Suite
    struct Test {
        @Suite struct Deterministic {}
        @Suite struct Sibling {}
    }
}

extension File.Path.Temporary.Test.Sibling {
    @Test
    func `Path has requested parent prefix and suffix`() throws {
        let destination = try File.Path("/work/Packages/swift-example")

        let temporary = try File.Path.Temporary.sibling(
            of: destination,
            prefix: ".workspace-swift-example-",
            suffix: ".clone"
        )

        #expect(temporary.parent == destination.parent)
        #expect(temporary.description.contains("/.workspace-swift-example-"))
        #expect(temporary.description.hasSuffix(".clone"))
    }

    @Test
    func `Successive paths are distinct`() throws {
        let destination = try File.Path("/work/Packages/swift-example")

        let first = try File.Path.Temporary.sibling(of: destination, prefix: ".workspace-")
        let second = try File.Path.Temporary.sibling(of: destination, prefix: ".workspace-")

        #expect(first != second)
    }
}

extension File.Path.Temporary.Test.Deterministic {
    @Test
    func `Same triple produces same path`() throws {
        let first = try File.Path.Temporary.deterministic(
            prefix: "swift-cohort-",
            key: "https://example.com/Lint.swift",
            suffix: ".tmp"
        )
        let second = try File.Path.Temporary.deterministic(
            prefix: "swift-cohort-",
            key: "https://example.com/Lint.swift",
            suffix: ".tmp"
        )
        #expect(first.description == second.description)
    }

    @Test
    func `Distinct keys produce distinct paths`() throws {
        let pathA = try File.Path.Temporary.deterministic(
            prefix: "swift-cohort-",
            key: "https://a.example.com/Lint.swift",
            suffix: ".tmp"
        )
        let pathB = try File.Path.Temporary.deterministic(
            prefix: "swift-cohort-",
            key: "https://b.example.com/Lint.swift",
            suffix: ".tmp"
        )
        #expect(pathA.description != pathB.description)
    }

    @Test
    func `Path embeds the prefix`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "swift-linter-fetch-",
            key: "anything",
            suffix: ".tmp"
        )
        #expect(path.description.contains("swift-linter-fetch-"))
    }

    @Test
    func `Path embeds the suffix`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "p-",
            key: "anything",
            suffix: ".dat"
        )
        #expect(path.description.hasSuffix(".dat"))
    }

    @Test
    func `Key with unsafe characters is sanitized`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "p-",
            key: "https://example.com/some/file.swift",
            suffix: ".tmp"
        )
        // Slashes / colons in the key map to underscores; the
        // resulting path must not contain runs of slash characters
        // beyond those introduced by the directory separator.
        let asString = path.description
        #expect(asString.contains("https___example.com_some_file.swift"))
    }

    @Test
    func `Key with NUL bytes is sanitized`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "p-",
            key: "before\0after",
            suffix: ".tmp"
        )
        #expect(!path.description.contains("\0"))
    }

    @Test
    func `Path is rooted at the platform temporary directory`() throws {
        let path = try File.Path.Temporary.deterministic(
            prefix: "p-",
            key: "anything",
            suffix: ".tmp"
        )
        // The platform temp root (TMPDIR or /tmp on POSIX; TEMP/TMP or
        // C:\Temp on Windows) plus a trailing segment matching the
        // prefix-key-suffix join.
        let asString = path.description
        #if os(Windows)
            #expect(asString.contains("\\p-anything.tmp"))
            // Rooted: either a drive-letter path (colon at index 1, e.g.
            // "C:\...") or a UNC/rooted path starting with a backslash.
            let isDriveLetterRooted =
                asString.count > 1
                && asString[asString.index(asString.startIndex, offsetBy: 1)] == ":"
            let isBackslashRooted = asString.hasPrefix("\\")
            #expect(isDriveLetterRooted || isBackslashRooted)
        #else
            #expect(asString.hasPrefix("/"))
            #expect(asString.contains("/p-anything.tmp"))
        #endif
    }
}
