//
//  File.Directory.Walk Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for directory walking.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if os(Windows)

    extension File.Directory.Walk.Test.Unit {

        // MARK: - Basic Walk Tests

        @Test("Walk empty directory")
        func walkEmptyDirectory() throws {
            try File.Directory.temporary { dir in
                let subdir = dir.path / "empty"
                try File.System.Create.Directory.create(at: subdir)

                let entries = try File.Directory.Walk.walk(at: File.Directory(subdir))
                #expect(entries.isEmpty)
            }
        }

        @Test("Walk directory with files")
        func walkDirectoryWithFiles() throws {
            try File.Directory.temporary { dir in
                // Create some files
                for i in 0..<3 {
                    let filePath = File.Path(dir.path, appending: "file\(i).txt")
                    try File.System.Write.Atomic.write([UInt8(i)], to: filePath)
                }

                let entries = try File.Directory.Walk.walk(at: dir)
                #expect(entries.count == 3)
            }
        }

        @Test("Walk directory with subdirectories")
        func walkDirectoryWithSubdirs() throws {
            try File.Directory.temporary { dir in
                // Create structure:
                // dir/
                //   file.txt
                //   subdir/
                //     nested.txt
                let filePath = File.Path(dir.path, appending: "file.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let nestedPath = File.Path(subPath, appending: "nested.txt")
                try File.System.Write.Atomic.write([2], to: nestedPath)

                let entries = try File.Directory.Walk.walk(at: dir)
                #expect(entries.count == 3)  // file.txt, subdir, nested.txt
            }
        }

        // MARK: - Options Tests

        @Test("Walk respects maxDepth")
        func walkRespectsMaxDepth() throws {
            try File.Directory.temporary { dir in
                // Create nested structure
                let subPath = dir.path / "level1"
                try File.System.Create.Directory.create(at: subPath)

                let sub2Path = subPath / "level2"
                try File.System.Create.Directory.create(at: sub2Path)

                let filePath = File.Path(sub2Path, appending: "deep.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                // maxDepth 0 should only return immediate children
                let options0 = File.Directory.Walk.Options(maxDepth: 0)
                let entries0 = try File.Directory.Walk.walk(at: dir, options: options0)
                #expect(entries0.count == 1)  // Just level1

                // maxDepth 1 should return level1 and level2
                let options1 = File.Directory.Walk.Options(maxDepth: 1)
                let entries1 = try File.Directory.Walk.walk(at: dir, options: options1)
                #expect(entries1.count == 2)  // level1, level2
            }
        }

        @Test("Walk can exclude hidden files")
        func walkExcludesHiddenFiles() throws {
            try File.Directory.temporary { dir in
                // Create visible and hidden files
                let visiblePath = File.Path(dir.path, appending: "visible.txt")
                try File.System.Write.Atomic.write([1], to: visiblePath)

                let hiddenPath = File.Path(dir.path, appending: ".hidden")
                try File.System.Write.Atomic.write([2], to: hiddenPath)

                // Without hidden files
                let optionsNoHidden = File.Directory.Walk.Options(includeHidden: false)
                let entriesNoHidden = try File.Directory.Walk.walk(at: dir, options: optionsNoHidden)
                #expect(entriesNoHidden.count == 1)

                // With hidden files
                let optionsWithHidden = File.Directory.Walk.Options(includeHidden: true)
                let entriesWithHidden = try File.Directory.Walk.walk(at: dir, options: optionsWithHidden)
                #expect(entriesWithHidden.count == 2)
            }
        }

        // MARK: - Windows-Specific Tests

        @Test("Walk handles Windows path separators")
        func walkHandlesWindowsPathSeparators() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let filePath = File.Path(subPath, appending: "file.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                // Walk should work regardless of path separator style
                let entries = try File.Directory.Walk.walk(at: dir)
                #expect(entries.count == 2)  // subdir, file.txt
            }
        }

        @Test("Walk handles files with spaces")
        func walkHandlesSpacesInNames() throws {
            try File.Directory.temporary { dir in
                let spaceName = "file with spaces.txt"
                let filePath = File.Path(dir.path, appending: spaceName)
                try File.System.Write.Atomic.write([1], to: filePath)

                let entries = try File.Directory.Walk.walk(at: dir)
                #expect(entries.count == 1)

                let entry = entries[0]
                #expect(String(entry.name) == spaceName)
            }
        }

        @Test("Walk handles deep nesting")
        func walkHandlesDeepNesting() throws {
            try File.Directory.temporary { dir in
                // Create a reasonably deep directory structure
                var currentPath = dir.path
                let depth = 10

                for i in 0..<depth {
                    currentPath = File.Path(currentPath, appending: "level\(i)")
                    try File.System.Create.Directory.create(at: currentPath)
                }

                // Create a file at the deepest level
                let filePath = File.Path(currentPath, appending: "deep.txt")
                try File.System.Write.Atomic.write([1], to: filePath)

                // Walk should find all directories and the file
                let entries = try File.Directory.Walk.walk(at: dir)
                #expect(entries.count == depth + 1)  // 10 dirs + 1 file
            }
        }
    }

#endif
