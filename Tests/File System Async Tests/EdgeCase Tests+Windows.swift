//
//  EdgeCase Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific async edge case tests.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System
@testable import File_System_Primitives

#if os(Windows)

    // MARK: - Windows Symlink Cycle Tests

    extension File.IO.Test.EdgeCase {

        // Helper to check if symlinks are available
        private static func canCreateSymlinks(at path: File.Path, io: File.IO.Executor) async throws -> Bool {
            let testLink = File.Path(path, appending: "symlink_test_\(Int.random(in: 0..<Int.max))")
            do {
                try await io.run {
                    try File.System.Link.Symbolic.create(at: testLink, pointingTo: path)
                }
                try? await io.run {
                    try File.System.Delete.delete(at: testLink)
                }
                return true
            } catch {
                return false
            }
        }

        @Test("Walk with symlink cycle - followSymlinks=false on Windows")
        func walkSymlinkCycleNoFollowWindows() async throws {
            try await File.Directory.temporary { dir in
                let io = File.IO.Executor()

                guard try await Self.canCreateSymlinks(at: dir.path, io: io) else {
                    // Skip test - insufficient privileges for symlinks
                    await io.shutdown()
                    return
                }

                // Create subdirectory
                let subPath = dir.path / "subdir"
                try await io.run {
                    try File.System.Create.Directory.create(at: subPath)
                }

                // Create symlink to parent (cycle)
                let linkPath = subPath / "parent-link"
                try await io.run {
                    try File.System.Link.Symbolic.create(at: linkPath, pointingTo: dir.path)
                }

                // Walk without following symlinks - should complete fine
                var count = 0
                let walk = File.Directory.Async(io: io).walk(
                    at: dir,
                    options: .init(followSymlinks: false)
                )
                let iterator = walk.makeAsyncIterator()
                while try await iterator.next() != nil {
                    count += 1
                }
                await iterator.terminate()

                // Should see: subdir + parent-link = 2
                #expect(count == 2)
                await io.shutdown()
            }
        }

        @Test("Walk with symlink cycle - followSymlinks=true detects cycle on Windows")
        func walkSymlinkCycleWithFollowWindows() async throws {
            try await File.Directory.temporary { dir in
                let io = File.IO.Executor()

                guard try await Self.canCreateSymlinks(at: dir.path, io: io) else {
                    await io.shutdown()
                    return
                }

                // Create subdirectory
                let subPath = dir.path / "subdir"
                try await io.run {
                    try File.System.Create.Directory.create(at: subPath)
                }

                // Create symlink to parent (cycle)
                let linkPath = subPath / "parent-link"
                try await io.run {
                    try File.System.Link.Symbolic.create(at: linkPath, pointingTo: dir.path)
                }

                // Create a file so we can verify walk works
                let filePath = dir.path / "file.txt"
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()

                // Walk with following symlinks - cycle detection should prevent infinite loop
                var count = 0
                let walk = File.Directory.Async(io: io).walk(
                    at: dir,
                    options: .init(followSymlinks: true)
                )
                let iterator = walk.makeAsyncIterator()
                while try await iterator.next() != nil {
                    count += 1
                    // Safety valve - if cycle detection fails, abort
                    if count > 100 {
                        Issue.record("Cycle detection failed - infinite loop detected")
                        break
                    }
                }
                await iterator.terminate()

                // Should complete without infinite loop
                #expect(count <= 10)  // Reasonable upper bound
                await io.shutdown()
            }
        }

        @Test("Async stat on symlink returns target info on Windows")
        func asyncStatSymlinkWindows() async throws {
            try await File.Directory.temporary { dir in
                let io = File.IO.Executor()

                guard try await Self.canCreateSymlinks(at: dir.path, io: io) else {
                    await io.shutdown()
                    return
                }

                // Create target file
                let targetPath = dir.path / "target.txt"
                let targetData: [UInt8] = [1, 2, 3, 4, 5]
                try await io.run {
                    try File.System.Write.Atomic.write(targetData, to: targetPath)
                }

                // Create symlink
                let linkPath = dir.path / "link.txt"
                try await io.run {
                    try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)
                }

                // Async stat should follow symlink
                let info = try await io.run {
                    try File.System.Stat.info(at: linkPath)
                }

                #expect(info.type == .regular)  // Target is a file
                #expect(info.size == Int64(targetData.count))

                await io.shutdown()
            }
        }
    }

    // MARK: - Windows-Specific Async Tests

    extension File.IO.Test.EdgeCase {

        @Test("Async walk handles Windows paths")
        func asyncWalkHandlesWindowsPaths() async throws {
            try await File.Directory.temporary { dir in
                let io = File.IO.Executor()

                // Create some files and directories
                let subPath = dir.path / "subdir"
                try await io.run {
                    try File.System.Create.Directory.create(at: subPath)
                }

                let filePath = File.Path(subPath, appending: "test file.txt")
                try await io.run {
                    try File.System.Write.Atomic.write([1, 2, 3], to: filePath)
                }

                var paths: [File.Path] = []
                let walk = File.Directory.Async(io: io).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                while let path = try await iterator.next() {
                    paths.append(path)
                }
                await iterator.terminate()

                #expect(paths.count == 2)  // subdir + test file.txt
                await io.shutdown()
            }
        }

        @Test("Async read handles Windows file locking")
        func asyncReadHandlesWindowsFileLocking() async throws {
            try await File.Directory.temporary { dir in
                let io = File.IO.Executor()

                let filePath = dir.path / "concurrent.txt"
                let testData: [UInt8] = Array(repeating: 0xAB, count: 1024)
                try await io.run {
                    try File.System.Write.Atomic.write(testData, to: filePath)
                }

                // Multiple concurrent reads should work
                await withTaskGroup(of: [UInt8].self) { group in
                    for _ in 0..<5 {
                        group.addTask {
                            (try? await io.run {
                                try File.System.Read.Full.read(from: filePath)
                            }) ?? []
                        }
                    }

                    var results: [[UInt8]] = []
                    for await result in group {
                        results.append(result)
                    }

                    for result in results {
                        #expect(result == testData)
                    }
                }

                await io.shutdown()
            }
        }
    }

#endif
