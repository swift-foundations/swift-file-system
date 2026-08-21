import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)

    extension File.Directory.Walk.Test.Unit {

        @Test
        func `Walk empty directory`() throws {
            try File.Directory.temporary { dir in
                let subdir = dir.path / "empty"
                try File.System.Create.Directory.create(at: subdir)

                let entries = try File.Directory(subdir).walk()
                #expect(entries.isEmpty)
            }
        }

        @Test
        func `Walk directory with files`() throws {
            try File.Directory.temporary { dir in

                for i in 0..<3 {
                    let filePath = dir.path / "file\(i).txt"
                    try File.System.Write.Atomic.write([Byte(UInt8(i))], to: filePath)
                }

                let entries = try dir.walk()
                #expect(entries.count == 3)
            }
        }

        @Test
        func `Walk directory with subdirectories`() throws {
            try File.Directory.temporary { dir in

                let filePath = dir.path / "file.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let nestedPath = subPath / "nested.txt"
                try File.System.Write.Atomic.write([2], to: nestedPath)

                let entries = try dir.walk()
                #expect(entries.count == 3)
            }
        }

        @Test
        func `Walk respects maxDepth`() throws {
            try File.Directory.temporary { dir in

                let subPath = dir.path / "level1"
                try File.System.Create.Directory.create(at: subPath)

                let sub2Path = subPath / "level2"
                try File.System.Create.Directory.create(at: sub2Path)

                let filePath = sub2Path / "deep.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let options0 = File.Directory.Walk.Options(maxDepth: 0)
                let entries0 = try dir.walk(options: options0)
                #expect(entries0.count == 1)

                let options1 = File.Directory.Walk.Options(maxDepth: 1)
                let entries1 = try dir.walk(options: options1)
                #expect(entries1.count == 2)
            }
        }

        @Test
        func `Walk can exclude hidden files`() throws {
            try File.Directory.temporary { dir in

                let visiblePath = dir.path / "visible.txt"
                try File.System.Write.Atomic.write([1], to: visiblePath)

                let hiddenPath = dir.path / ".hidden"
                try File.System.Write.Atomic.write([2], to: hiddenPath)

                let optionsNoHidden = File.Directory.Walk.Options(includeHidden: false)
                let entriesNoHidden = try dir.walk(options: optionsNoHidden)
                #expect(entriesNoHidden.count == 1)

                let optionsWithHidden = File.Directory.Walk.Options(includeHidden: true)
                let entriesWithHidden = try dir.walk(options: optionsWithHidden)
                #expect(entriesWithHidden.count == 2)
            }
        }

        @Test
        func `Walk handles Windows path separators`() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let filePath = subPath / "file.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let entries = try dir.walk()
                #expect(entries.count == 2)
            }
        }

        @Test
        func `Walk handles files with spaces`() throws {
            try File.Directory.temporary { dir in
                let spaceName = "file with spaces.txt"
                let filePath = dir.path / "\(spaceName)"
                try File.System.Write.Atomic.write([1], to: filePath)

                let entries = try dir.walk()
                #expect(entries.count == 1)

                let entry = entries[0]
                #expect(Swift.String(entry.name) == spaceName)
            }
        }

        @Test
        func `Walk handles deep nesting`() throws {
            try File.Directory.temporary { dir in

                var currentPath = dir.path
                let depth = 10

                for i in 0..<depth {
                    let component: File.Path.Component = "level\(i)"
                    currentPath = currentPath.appending(component)
                    try File.System.Create.Directory.create(at: currentPath)
                }

                let filePath = currentPath / "deep.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let entries = try dir.walk()
                #expect(entries.count == depth + 1)
            }
        }
    }

#endif
