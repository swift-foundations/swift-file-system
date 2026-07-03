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
        #else
            #expect(asString.hasPrefix("/"))
            #expect(asString.contains("/p-anything.tmp"))
        #endif
    }
}
