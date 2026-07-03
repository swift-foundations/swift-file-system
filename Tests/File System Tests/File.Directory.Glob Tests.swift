// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if !os(Windows)

    import Testing

    import Kernel
    @testable import File_System
    @testable import File_System_Core
    import File_System_Test_Support

    extension File.Directory.Glob {
        @Suite
        struct Test {
            @Suite struct Unit {}
            @Suite struct EdgeCase {}
            @Suite struct Integration {}
            @Suite(.serialized) struct Performance {}
        }
    }

    // MARK: - Unit Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `Glob namespace is accessible via directory.glob`() throws {
            try File.Directory.temporary { dir in
                let glob = dir.glob
                _ = glob
            }
        }

        @Test
        func `Match simple wildcard pattern`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["*.txt"])

                #expect(matches.count == 2)
                #expect(matches.allSatisfy { $0.isFile })

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/file1.txt") }))
                #expect(paths.contains(where: { $0.hasSuffix("/file2.txt") }))
            }
        }

        @Test
        func `Match question mark wildcard`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["file?.txt"])

                #expect(matches.count == 2)

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/file1.txt") }))
                #expect(paths.contains(where: { $0.hasSuffix("/file2.txt") }))
            }
        }

        @Test
        func `Match literal pattern`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["file1.txt"])

                #expect(matches.count == 1)
                #expect(matches[0].isFile)
                #expect(Swift.String(matches[0].path).hasSuffix("/file1.txt"))
            }
        }

        @Test
        func `Match with path segments`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["src/*.swift"])

                #expect(matches.count == 3)

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/src/main.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/test.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/util.swift") }))
            }
        }

        @Test
        func `Match returns empty for no matches`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["*.xyz"])

                #expect(matches.isEmpty)
            }
        }
    }

    // MARK: - Double Star Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `Match double star recursive`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["**/*.swift"])

                #expect(matches.count == 3)

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/src/main.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/test.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/util.swift") }))
            }
        }

        @Test
        func `Match double star finds all md files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["**/*.md"])

                #expect(matches.count == 3)

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/file3.md") }))
                #expect(paths.contains(where: { $0.hasSuffix("/docs/readme.md") }))
                #expect(paths.contains(where: { $0.hasSuffix("/docs/guide.md") }))
            }
        }
    }

    // MARK: - Files Variant Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `files() returns only files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let files = try dir.glob.files(include: ["*"])

                // Should only return files, not directories
                #expect(files.count == 3)  // file1.txt, file2.txt, file3.md

                // All results are File type (not Directory)
                for file in files {
                    #expect(!File.System.Stat.isDirectory(at: file.path))
                }
            }
        }

        @Test
        func `files() recursive finds all swift files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let files = try dir.glob.files(include: ["**/*.swift"])

                #expect(files.count == 3)

                let paths = files.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/src/main.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/test.swift") }))
                #expect(paths.contains(where: { $0.hasSuffix("/src/util.swift") }))
            }
        }
    }

    // MARK: - Directories Variant Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `directories() returns only directories`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let dirs = try dir.glob.directories(include: ["*"])

                // Should only return directories: src, docs
                #expect(dirs.count == 2)

                let paths = dirs.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/src") }))
                #expect(paths.contains(where: { $0.hasSuffix("/docs") }))
            }
        }

        @Test
        func `directories() recursive finds all subdirectories`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let dirs = try dir.glob.directories(include: ["**/*"])

                // Should find: src, docs (excluding hidden .config)
                #expect(dirs.count >= 2)

                let paths = dirs.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/src") }))
                #expect(paths.contains(where: { $0.hasSuffix("/docs") }))
            }
        }
    }

    // MARK: - Match Type Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `Match.isFile returns true for files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["file1.txt"])

                #expect(matches.count == 1)
                #expect(matches[0].isFile == true)
                #expect(matches[0].isDirectory == false)
                #expect(matches[0].file != nil)
                #expect(matches[0].subdirectory == nil)
            }
        }

        @Test
        func `Match.isDirectory returns true for directories`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["src"])

                #expect(matches.count == 1)
                #expect(matches[0].isFile == false)
                #expect(matches[0].isDirectory == true)
                #expect(matches[0].file == nil)
                #expect(matches[0].subdirectory != nil)
            }
        }

        @Test
        func `Match.path returns absolute path`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["file1.txt"])

                #expect(matches.count == 1)
                let pathString = Swift.String(matches[0].path)
                #expect(pathString.hasPrefix("/"))
                #expect(pathString.hasSuffix("/file1.txt"))
            }
        }
    }

    // MARK: - Include/Exclude Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `Match with exclusion pattern`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(
                    include: ["*.txt"],
                    excluding: ["file1.txt"]
                )

                #expect(matches.count == 1)
                #expect(Swift.String(matches[0].path).hasSuffix("/file2.txt"))
            }
        }

        @Test
        func `Match with multiple include patterns`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["*.txt", "*.md"])

                #expect(matches.count == 3)

                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/file1.txt") }))
                #expect(paths.contains(where: { $0.hasSuffix("/file2.txt") }))
                #expect(paths.contains(where: { $0.hasSuffix("/file3.md") }))
            }
        }

        @Test
        func `Match with multiple exclude patterns`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(
                    include: ["**/*.swift"],
                    excluding: ["**/main.swift", "**/test.swift"]
                )

                #expect(matches.count == 1)
                #expect(Swift.String(matches[0].path).hasSuffix("/src/util.swift"))
            }
        }
    }

    // MARK: - Options Tests

    extension File.Directory.Glob.Test.Unit {
        @Test
        func `Dotfiles explicit policy excludes hidden files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let options = Glob.Options(dotfiles: .explicit)
                let matches = try dir.glob(include: ["*.txt"], options: options)

                // Should not include .hidden.txt
                #expect(matches.count == 2)
                let paths = matches.map { Swift.String($0.path) }
                #expect(!paths.contains(where: { $0.hasSuffix("/.hidden.txt") }))
            }
        }

        @Test
        func `Dotfiles always policy includes hidden files`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let options = Glob.Options(dotfiles: .always)
                let matches = try dir.glob(include: ["*.txt"], options: options)

                // Should include .hidden.txt
                #expect(matches.count == 3)
                let paths = matches.map { Swift.String($0.path) }
                #expect(paths.contains(where: { $0.hasSuffix("/.hidden.txt") }))
            }
        }

        @Test
        func `Deterministic ordering sorts results`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let options = Glob.Options(ordering: .deterministic)
                let matches = try dir.glob(include: ["*.txt"], options: options)

                // Results should be sorted
                let paths = matches.map { Swift.String($0.path) }
                #expect(paths == paths.sorted())
            }
        }
    }

    // MARK: - Edge Cases

    extension File.Directory.Glob.Test.EdgeCase {
        @Test
        func `Match empty pattern`() throws {
            try File.Directory.temporary { dir in
                let matches = try dir.glob(include: [""])

                // Empty pattern matches the directory itself
                #expect(matches.count == 1)
            }
        }

        @Test
        func `Match pattern with only star`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["*"])

                // Should match all non-hidden files and directories at root
                #expect(matches.count >= 4)  // file1.txt, file2.txt, file3.md, src/, docs/
            }
        }

        @Test
        func `Match Equatable conformance`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches1 = try dir.glob(include: ["file1.txt"])
                let matches2 = try dir.glob(include: ["file1.txt"])

                #expect(matches1 == matches2)
            }
        }

        @Test
        func `Match Hashable conformance`() throws {
            try File.Directory.temporary { dir in
                try createGlobTestFiles(in: dir)

                let matches = try dir.glob(include: ["*.txt"])
                let matchSet = Set(matches)

                #expect(matchSet.count == matches.count)
            }
        }
    }

#endif
