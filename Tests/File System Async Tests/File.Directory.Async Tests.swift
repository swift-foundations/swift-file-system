//
//  File.Directory.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing

@testable import File_System_Async

extension File.Directory.Async {
    #TestSuites
}

extension File.Directory.Async.Test.Unit {

    // MARK: - Shared Test Fixtures

    static func createTempDir() throws -> File.Path {
        let path = try File.Path("/tmp/async-dir-test-\(Int.random(in: 0..<Int.max))")
        try File.System.Create.Directory.create(at: path)
        return path
    }

    static func createFile(in dir: File.Path, name: String, content: String = "") throws {
        let filePath = try File.Path(dir.string + "/" + name)
        let bytes = Array(content.utf8)
        try bytes.withUnsafeBufferPointer { buffer in
            let span = Span<UInt8>(_unsafeElements: buffer)
            try File.System.Write.Atomic.write(span, to: filePath)
        }
    }

    static func createSubdir(in dir: File.Path, name: String) throws -> File.Path {
        let subPath = try File.Path(dir.string + "/" + name)
        try File.System.Create.Directory.create(at: subPath)
        return subPath
    }

    static func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path, options: .init(recursive: true))
    }

    // MARK: - Walk Suite

    @Suite
    struct Walk {

        @Test("Walk empty directory")
        func emptyDirectory() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            let walk = File.Directory.Async(io: io).walk(at: dir)
            var count = 0

            for try await _ in walk {
                count += 1
            }

            #expect(count == 0)
        }

        @Test("Walk directory with files")
        func directoryWithFiles() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file1.txt")
            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file2.txt")
            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file3.txt")

            let walk = File.Directory.Async(io: io).walk(at: dir)
            var paths: [String] = []

            for try await path in walk {
                paths.append(path.string)
            }

            #expect(paths.count == 3)
        }

        @Test("Walk directory recursively")
        func directoryRecursively() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            // Create structure:
            // dir/
            //   file1.txt
            //   subdir1/
            //     file2.txt
            //     subsubdir/
            //       file3.txt
            //   subdir2/
            //     file4.txt

            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file1.txt")

            let sub1 = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "subdir1")
            try File.Directory.Async.Test.Unit.createFile(in: sub1, name: "file2.txt")

            let subsub = try File.Directory.Async.Test.Unit.createSubdir(
                in: sub1,
                name: "subsubdir"
            )
            try File.Directory.Async.Test.Unit.createFile(in: subsub, name: "file3.txt")

            let sub2 = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "subdir2")
            try File.Directory.Async.Test.Unit.createFile(in: sub2, name: "file4.txt")

            let walk = File.Directory.Async(io: io).walk(at: dir)
            var paths: Set<String> = []

            for try await path in walk {
                paths.insert(path.string)
            }

            // Should find: subdir1, file2.txt, subsubdir, file3.txt, subdir2, file4.txt, file1.txt
            // (7 entries total)
            #expect(paths.count == 7)
            #expect(paths.contains(dir.string + "/file1.txt"))
            #expect(paths.contains(dir.string + "/subdir1"))
            #expect(paths.contains(dir.string + "/subdir1/file2.txt"))
            #expect(paths.contains(dir.string + "/subdir1/subsubdir"))
            #expect(paths.contains(dir.string + "/subdir1/subsubdir/file3.txt"))
            #expect(paths.contains(dir.string + "/subdir2"))
            #expect(paths.contains(dir.string + "/subdir2/file4.txt"))
        }

        @Test("Walk non-existent directory throws")
        func nonExistentThrows() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let path = try File.Path("/tmp/nonexistent-\(Int.random(in: 0..<Int.max))")

            let walk = File.Directory.Async(io: io).walk(at: path)

            await #expect(throws: (any Error).self) {
                for try await _ in walk {
                    // Should throw
                }
            }
        }

        @Test("Walk large directory tree")
        func largeTree() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            // Create 10 subdirs, each with 10 files
            for i in 0..<10 {
                let sub = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "dir\(i)")
                for j in 0..<10 {
                    try File.Directory.Async.Test.Unit.createFile(in: sub, name: "file\(j).txt")
                }
            }

            let walk = File.Directory.Async(io: io).walk(at: dir)
            var count = 0

            for try await _ in walk {
                count += 1
            }

            // 10 subdirs + 100 files = 110 entries
            #expect(count == 110)
        }

        @Test("Walk with custom concurrency")
        func withCustomConcurrency() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            for i in 0..<5 {
                let sub = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "dir\(i)")
                try File.Directory.Async.Test.Unit.createFile(in: sub, name: "file.txt")
            }

            let options = File.Directory.Async.WalkOptions(maxConcurrency: 2)
            let walk = File.Directory.Async(io: io).walk(at: dir, options: options)
            var count = 0

            for try await _ in walk {
                count += 1
            }

            // 5 subdirs + 5 files = 10 entries
            #expect(count == 10)
        }
    }

    // MARK: - Contents Suite

    @Suite
    struct Contents {

        @Test("Entries stream empty directory")
        func emptyDirectory() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var count = 0

            for try await _ in entries {
                count += 1
            }

            #expect(count == 0)
        }

        @Test("Entries stream directory with files")
        func directoryWithFiles() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            try File.Directory.Async.Test.Unit.createFile(
                in: dir,
                name: "file1.txt",
                content: "hello"
            )
            try File.Directory.Async.Test.Unit.createFile(
                in: dir,
                name: "file2.txt",
                content: "world"
            )
            try File.Directory.Async.Test.Unit.createFile(
                in: dir,
                name: "file3.txt",
                content: "test"
            )

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var names: [String] = []

            for try await entry in entries {
                if let name = String(entry.name) {
                    names.append(name)
                }
            }

            #expect(names.count == 3)
            #expect(names.contains("file1.txt"))
            #expect(names.contains("file2.txt"))
            #expect(names.contains("file3.txt"))
        }

        @Test("Entries stream directory with subdirectories")
        func directoryWithSubdirs() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file.txt")
            _ = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "subdir1")
            _ = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "subdir2")

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var files: [String] = []
            var dirs: [String] = []

            for try await entry in entries {
                if let name = String(entry.name) {
                    if entry.type == .file {
                        files.append(name)
                    } else if entry.type == .directory {
                        dirs.append(name)
                    }
                }
            }

            #expect(files.count == 1)
            #expect(files.contains("file.txt"))
            #expect(dirs.count == 2)
            #expect(dirs.contains("subdir1"))
            #expect(dirs.contains("subdir2"))
        }

        @Test("Entries non-existent directory throws")
        func nonExistentThrows() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let path = try File.Path("/tmp/nonexistent-\(Int.random(in: 0..<Int.max))")

            let entries = File.Directory.Async(io: io).entries(at: path)

            await #expect(throws: (any Error).self) {
                for try await _ in entries {
                    // Should throw before yielding
                }
            }
        }

        @Test("Entries stream large directory")
        func largeDirectory() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            // Create 100 files
            for i in 0..<100 {
                try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file\(i).txt")
            }

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var count = 0

            for try await _ in entries {
                count += 1
            }

            #expect(count == 100)
        }
    }

    // MARK: - Entry Suite

    @Suite
    struct Entry {

        @Test("Entries entry has correct path")
        func hasCorrectPath() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            try File.Directory.Async.Test.Unit.createFile(in: dir, name: "test.txt")

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var foundEntry: File.Directory.Entry?

            for try await entry in entries {
                foundEntry = entry
            }

            #expect(foundEntry != nil)
            #expect(foundEntry?.pathIfValid?.string == dir.string + "/test.txt")
        }
    }

    // MARK: - Iterator Suite

    @Suite
    struct Iterator {

        @Test("Walk terminate stops iteration")
        func walkTerminateStops() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            // Create nested structure
            for i in 0..<5 {
                let sub = try File.Directory.Async.Test.Unit.createSubdir(in: dir, name: "dir\(i)")
                for j in 0..<5 {
                    try File.Directory.Async.Test.Unit.createFile(in: sub, name: "file\(j).txt")
                }
            }

            let walk = File.Directory.Async(io: io).walk(at: dir)
            let iterator = walk.makeAsyncIterator()
            var count = 0

            // Read a few paths
            while try await iterator.next() != nil, count < 10 {
                count += 1
            }

            // Explicitly terminate
            iterator.terminate()

            // After termination, next() should return nil
            let afterTerminate = try await iterator.next()
            #expect(afterTerminate == nil)
        }

        @Test("Walk break from loop cleans up")
        func walkBreakCleansUp() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            for i in 0..<10 {
                try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file\(i).txt")
            }

            let walk = File.Directory.Async(io: io).walk(at: dir)
            var count = 0

            for try await _ in walk {
                count += 1
                if count >= 5 {
                    break
                }
            }

            #expect(count == 5)
        }

        @Test("Entries terminate stops iteration")
        func entriesTerminateStops() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            // Create many files
            for i in 0..<10 {
                try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file\(i).txt")
            }

            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()
            var count = 0

            // Read a few entries
            while try await iterator.next() != nil, count < 3 {
                count += 1
            }

            // Explicitly terminate
            iterator.terminate()

            // After termination, next() should return nil
            let afterTerminate = try await iterator.next()
            #expect(afterTerminate == nil)
        }

        @Test("Entries terminate is idempotent")
        func entriesTerminateIsIdempotent() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()

            // Terminate multiple times - should not crash
            iterator.terminate()
            iterator.terminate()
            iterator.terminate()

            let result = try await iterator.next()
            #expect(result == nil)
        }

        @Test("Entries break from loop cleans up")
        func entriesBreakCleansUp() async throws {
            let io = File.IO.Executor()
            defer { Task { await io.shutdown() } }

            let dir = try File.Directory.Async.Test.Unit.createTempDir()
            defer { File.Directory.Async.Test.Unit.cleanup(dir) }

            for i in 0..<10 {
                try File.Directory.Async.Test.Unit.createFile(in: dir, name: "file\(i).txt")
            }

            let entries = File.Directory.Async(io: io).entries(at: dir)
            var count = 0

            for try await _ in entries {
                count += 1
                if count >= 3 {
                    break
                }
            }

            #expect(count == 3)
        }
    }
}
