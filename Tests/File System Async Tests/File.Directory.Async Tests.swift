//
//  File.Directory.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System
import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Async

extension File.Directory.Async {
    #TestSuites
}

extension File.Directory.Async.Test.Unit {

    // MARK: - Walk Suite

    @Suite
    struct Walk {

        @Test("Walk empty directory")
        func emptyDirectory() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var count = 0

                while try await iterator.next() != nil {
                    count += 1
                }
                await iterator.terminate()

                #expect(count == 0)
                await fs.shutdown()
            }
        }

        @Test("Walk directory with files")
        func directoryWithFiles() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "file1.txt"
                )
                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "file2.txt"
                )
                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "file3.txt"
                )

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var paths: [String] = []

                while let path = try await iterator.next() {
                    paths.append(String(path))
                }
                await iterator.terminate()

                #expect(paths.count == 3)
                await fs.shutdown()
            }
        }

        @Test("Walk directory recursively")
        func directoryRecursively() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create structure:
                // dir/
                //   file1.txt
                //   subdir1/
                //     file2.txt
                //     subsubdir/
                //       file3.txt
                //   subdir2/
                //     file4.txt

                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "file1.txt"
                )

                let sub1 = dir.path / "subdir1"
                try await File.System.Create.Directory.create(at: sub1)
                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: sub1 / "file2.txt"
                )

                let subsub = sub1 / "subsubdir"
                try await File.System.Create.Directory.create(at: subsub)
                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: subsub / "file3.txt"
                )

                let sub2 = dir.path / "subdir2"
                try await File.System.Create.Directory.create(at: sub2)
                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: sub2 / "file4.txt"
                )

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var paths: Set<String> = []

                while let path = try await iterator.next() {
                    paths.insert(String(path))
                }
                await iterator.terminate()

                // Should find: subdir1, file2.txt, subsubdir, file3.txt, subdir2, file4.txt, file1.txt
                // (7 entries total)
                #expect(paths.count == 7)
                #expect(paths.contains(String(dir.path / "file1.txt")))
                #expect(paths.contains(String(dir.path / "subdir1")))
                #expect(paths.contains(String(dir.path / "subdir1" / "file2.txt")))
                #expect(paths.contains(String(dir.path / "subdir1" / "subsubdir")))
                #expect(paths.contains(String(dir.path / "subdir1" / "subsubdir" / "file3.txt")))
                #expect(paths.contains(String(dir.path / "subdir2")))
                #expect(paths.contains(String(dir.path / "subdir2" / "file4.txt")))
                await fs.shutdown()
            }
        }

        @Test("Walk non-existent directory throws")
        func nonExistentThrows() async throws {
            let fs = File.System.Async()

            let path = try File.Path("/tmp/nonexistent-\(Int.random(in: 0..<Int.max))")

            let walk = File.Directory.Async(fs: fs).walk(at: File.Directory(path))
            let iterator = walk.makeAsyncIterator()

            do {
                while try await iterator.next() != nil {
                    Issue.record("Should throw before yielding")
                }
                await iterator.terminate()
                await fs.shutdown()
            } catch {
                // Expected - should throw
                await iterator.terminate()
                await fs.shutdown()
            }
        }

        @Test("Walk large directory tree")
        func largeTree() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create 10 subdirs, each with 10 files
                for i in 0..<10 {
                    let sub = dir.path / "dir\(i)"
                    try await File.System.Create.Directory.create(at: sub)
                    for j in 0..<10 {
                        try File.System.Write.Atomic.write(
                            Array("".utf8).span,
                            to: sub / "file\(j).txt"
                        )
                    }
                }

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var count = 0

                while try await iterator.next() != nil {
                    count += 1
                }
                await iterator.terminate()

                // 10 subdirs + 100 files = 110 entries
                #expect(count == 110)
                await fs.shutdown()
            }
        }

        @Test("Walk with custom concurrency")
        func withCustomConcurrency() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                for i in 0..<5 {
                    let sub = dir.path / "dir\(i)"
                    try await File.System.Create.Directory.create(at: sub)
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: sub / "file.txt"
                    )
                }

                let options = File.Directory.Walk.Async.Options(maxConcurrency: 2)
                let walk = File.Directory.Async(fs: fs).walk(at: dir, options: options)
                let iterator = walk.makeAsyncIterator()
                var count = 0

                while try await iterator.next() != nil {
                    count += 1
                }
                await iterator.terminate()

                // 5 subdirs + 5 files = 10 entries
                #expect(count == 10)
                await fs.shutdown()
            }
        }
    }

    // MARK: - Contents Suite

    @Suite
    struct Contents {

        @Test("Entries stream empty directory")
        func emptyDirectory() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                var count = 0

                for try await _ in entries {
                    count += 1
                }

                #expect(count == 0)
                await fs.shutdown()
            }
        }

        @Test("Entries stream directory with files")
        func directoryWithFiles() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                try File.System.Write.Atomic.write(
                    Array("hello".utf8).span,
                    to: dir.path / "file1.txt"
                )
                try File.System.Write.Atomic.write(
                    Array("world".utf8).span,
                    to: dir.path / "file2.txt"
                )
                try File.System.Write.Atomic.write(
                    Array("test".utf8).span,
                    to: dir.path / "file3.txt"
                )

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
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
                await fs.shutdown()
            }
        }

        @Test("Entries stream directory with subdirectories")
        func directoryWithSubdirs() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "file.txt"
                )
                try await File.System.Create.Directory.create(at: dir.path / "subdir1")
                try await File.System.Create.Directory.create(at: dir.path / "subdir2")

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
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
                await fs.shutdown()
            }
        }

        @Test("Entries non-existent directory throws")
        func nonExistentThrows() async throws {
            let fs = File.System.Async()

            let path = try File.Path("/tmp/nonexistent-\(Int.random(in: 0..<Int.max))")

            let entries = File.Directory.Async(fs: fs).entries(at: File.Directory(path))
            let iterator = entries.makeAsyncIterator()

            do {
                while try await iterator.next() != nil {
                    Issue.record("Should throw before yielding")
                }
                await iterator.terminate()
                await fs.shutdown()
            } catch {
                // Expected - should throw
                await iterator.terminate()
                await fs.shutdown()
            }
        }

        @Test("Entries stream large directory")
        func largeDirectory() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create 100 files
                for i in 0..<100 {
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: dir.path / "file\(i).txt"
                    )
                }

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                var count = 0

                for try await _ in entries {
                    count += 1
                }

                #expect(count == 100)
                await fs.shutdown()
            }
        }
    }

    // MARK: - Entry Suite

    @Suite
    struct Entry {

        @Test("Entries entry has correct path")
        func hasCorrectPath() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                try File.System.Write.Atomic.write(
                    Array("".utf8).span,
                    to: dir.path / "test.txt"
                )

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                var foundEntry: File.Directory.Entry?

                for try await entry in entries {
                    foundEntry = entry
                }

                #expect(foundEntry != nil)
                #expect(foundEntry?.pathIfValid == dir.path / "test.txt")
                await fs.shutdown()
            }
        }
    }

    // MARK: - Iterator Suite

    @Suite
    struct Iterator {

        @Test("Walk terminate stops iteration")
        func walkTerminateStops() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create nested structure
                for i in 0..<5 {
                    let sub = dir.path / "dir\(i)"
                    try await File.System.Create.Directory.create(at: sub)
                    for j in 0..<5 {
                        try File.System.Write.Atomic.write(
                            Array("".utf8).span,
                            to: sub / "file\(j).txt"
                        )
                    }
                }

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var count = 0

                // Read a few paths
                while try await iterator.next() != nil, count < 10 {
                    count += 1
                }

                // Explicitly terminate
                await iterator.terminate()

                // After termination, next() should return nil
                let afterTerminate = try await iterator.next()
                #expect(afterTerminate == nil)
                await fs.shutdown()
            }
        }

        @Test("Walk break from loop cleans up")
        func walkBreakCleansUp() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                for i in 0..<10 {
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: dir.path / "file\(i).txt"
                    )
                }

                let walk = File.Directory.Async(fs: fs).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                var count = 0

                while try await iterator.next() != nil {
                    count += 1
                    if count >= 5 {
                        break
                    }
                }
                await iterator.terminate()

                #expect(count == 5)
                await fs.shutdown()
            }
        }

        @Test("Entries terminate stops iteration")
        func entriesTerminateStops() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create many files
                for i in 0..<10 {
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: dir.path / "file\(i).txt"
                    )
                }

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                var count = 0

                // Read a few entries
                while try await iterator.next() != nil, count < 3 {
                    count += 1
                }

                // Explicitly terminate
                await iterator.terminate()

                // After termination, next() should return nil
                let afterTerminate = try await iterator.next()
                #expect(afterTerminate == nil)
                await fs.shutdown()
            }
        }

        @Test("Entries terminate is idempotent")
        func entriesTerminateIsIdempotent() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                let iterator = entries.makeAsyncIterator()

                // Terminate multiple times - should not crash
                await iterator.terminate()
                await iterator.terminate()
                await iterator.terminate()

                let result = try await iterator.next()
                #expect(result == nil)
                await fs.shutdown()
            }
        }

        @Test("Entries break from loop cleans up")
        func entriesBreakCleansUp() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                for i in 0..<10 {
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: dir.path / "file\(i).txt"
                    )
                }

                let entries = File.Directory.Async(fs: fs).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                var count = 0

                while try await iterator.next() != nil {
                    count += 1
                    if count >= 3 {
                        break
                    }
                }
                await iterator.terminate()

                #expect(count == 3)
                await fs.shutdown()
            }
        }

        @Test("Entries cancellation cleans up")
        func entriesCancellationCleansUp() async throws {
            try await File.Directory.temporary { dir in
                let fs = File.System.Async()

                // Create many files to ensure iteration takes time
                for i in 0..<100 {
                    try File.System.Write.Atomic.write(
                        Array("".utf8).span,
                        to: dir.path / "file\(i).txt"
                    )
                }

                let entries = File.Directory.Async(fs: fs).entries(at: dir)

                // Start iteration in a task we can cancel
                let task = Task {
                    var count = 0
                    let iterator = entries.makeAsyncIterator()
                    do {
                        while try await iterator.next() != nil {
                            count += 1
                            // Yield to allow cancellation to be processed
                            await Task.yield()
                        }
                    } catch {
                        await iterator.terminate()
                        throw error
                    }
                    return count
                }

                // Let it run briefly then cancel
                try await Task.sleep(for: .milliseconds(10))
                task.cancel()

                // Should throw CancellationError or return partial count
                do {
                    let count = try await task.value
                    // If it didn't throw, it completed before cancellation
                    #expect(count <= 100)
                } catch is CancellationError {
                    // Expected - raw cancellation
                } catch let error as IO.Lifecycle.Error<IO.Error<File.Directory.Iterator.Error>> {
                    // Expected - wrapped cancellation from iterator
                    guard case .failure(.cancelled) = error else {
                        Issue.record("Expected .failure(.cancelled), got \(error)")
                        await fs.shutdown()
                        return
                    }
                }
                await fs.shutdown()
            }
        }
    }
}
