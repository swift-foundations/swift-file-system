import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)

    extension File.System.Link.Symbolic.Test.Unit {

        private static func canCreateSymlinks(in dir: File.Directory) -> Bool {
            let testFile = dir.path / "symlink_test_target_\(Int.random(in: (0..<Int.max))).txt"
            let testLink = dir.path / "symlink_test_link_\(Int.random(in: (0..<Int.max))).lnk"
            defer {
                try? File.System.Delete.delete(at: testLink)
                try? File.System.Delete.delete(at: testFile)
            }
            do {

                try File.System.Write.Atomic.write([1, 2, 3], to: testFile)
                try File.System.Link.Symbolic.create(at: testLink, pointingTo: testFile)

                let info = try File.System.Stat.info(at: testLink, followSymlinks: false)
                return info.type == .symbolicLink
            } catch {
                return false
            }
        }

        @Test
        func `Create symlink to file`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {

                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                #expect(File.System.Stat.exists(at: linkPath))

                let data = try File.System.Read.Full.read(from: linkPath) {
                    $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
                }
                #expect(data == [1, 2, 3])
            }
        }

        @Test
        func `Create symlink to directory`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target_dir"
                try File.System.Create.Directory.create(at: targetPath)

                let filePath = targetPath / "file.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                let linkPath = dir.path / "link_dir"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                #expect(File.System.Stat.exists(at: linkPath))

                let linkedFilePath = linkPath / "file.txt"
                let data = try File.System.Read.Full.read(from: linkedFilePath) {
                    $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
                }
                #expect(data == [1])
            }
        }

        @Test
        func `Read symlink target`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let target = try File.System.Link.Read.Target.target(of: linkPath)

                #expect(Swift.String(target).contains("target.txt"))
            }
        }

        @Test
        func `Stat on symlink follows link by default`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath)
                #expect(info.type == .regular)
                #expect(info.size == 5)
            }
        }

        @Test
        func `info(followSymlinks: false) on symlink returns symlink info`() throws {
            try File.Directory.temporary { dir in
                guard Self.canCreateSymlinks(in: dir) else {
                    return
                }

                let targetPath = dir.path / "target.txt"
                try File.System.Write.Atomic.write([1, 2, 3, 4, 5], to: targetPath)

                let linkPath = dir.path / "link.txt"
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

                let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
                #expect(info.type == .symbolicLink)
            }
        }

        @Test
        func `Read target of non-symlink fails`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "regular.txt"
                try File.System.Write.Atomic.write([1], to: filePath)

                do throws(File.System.Link.Read.Target.Error) {
                    _ = try File.System.Link.Read.Target.target(of: filePath)
                    Issue.record("Expected error for non-symlink")
                } catch {
                    #expect(error.isNotASymlink)
                }
            }
        }

        @Test
        func `Read target of non-existent path fails`() throws {
            try File.Directory.temporary { dir in
                let nonExistent = dir.path / "nonexistent"

                do throws(File.System.Link.Read.Target.Error) {
                    _ = try File.System.Link.Read.Target.target(of: nonExistent)
                    Issue.record("Expected error for non-existent path")
                } catch {
                    #expect(error.isNotFound)
                }
            }
        }
    }

#endif
