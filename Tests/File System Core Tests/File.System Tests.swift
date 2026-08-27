import File_System_Test_Support
import Kernel
import Tagged_Standard_Library_Integration
import Testing

@testable import File_System_Core

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension File.System {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Test.Unit {
    @Test
    func `Same recognizes one object through distinct paths`() throws {
        try File.Directory.temporary { directory in
            let first = directory.path
            let second = try directory.path.appending(".")

            #expect(try File.System.same(first, second))
        }
    }

    @Test
    func `Same rejects distinct objects`() throws {
        try File.Directory.temporary { first in
            try File.Directory.temporary { second in
                let same = try File.System.same(first.path, second.path)
                #expect(!same)
            }
        }
    }
}

#if os(macOS) || os(Linux)

    extension File.System.Test.`Edge Case` {

        private func createTempPath() -> Swift.String {
            "/tmp/edge-test-\(Int.random(in: (0..<Int.max)))"
        }

        private func cleanup(_ path: Swift.String) {
            if let filePath = try? File.Path(path) {
                try? File.System.Delete.delete(at: filePath, recursive: true)
            }
        }

        private func cleanupPath(_ path: File.Path) {
            try? File.System.Delete.delete(at: path, recursive: true)
        }

        @Test
        func `Read from empty file returns zero bytes`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try handle.close()

            var readHandle = try File.Handle.open(filePath, mode: .read)

            var buffer = [Byte](repeating: 0, count: 1024)
            let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
                try readHandle.read(into: ptr)
            }

            try readHandle.close()

            #expect(bytesRead == 0)
        }

        @Test
        func `Write zero bytes succeeds`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )

            let emptyArray: [Byte] = []
            try handle.write(emptyArray.span)

            try handle.close()

            let info = try File.System.Stat.info(at: filePath)
            #expect(info.size == 0)
        }

        @Test
        func `Path with embedded NUL byte is rejected`() throws {
            let pathWithNul = "/tmp/test\0hidden"

            #expect(throws: File.Path.Error.self) {
                _ = try File.Path(pathWithNul)
            }
        }

        @Test
        func `Empty path is rejected`() throws {
            let emptyString = ""
            var didThrow = false
            do throws(File.Path.Error) {
                _ = try File.Path(emptyString)
            } catch {
                didThrow = true
            }
            #expect(didThrow)
        }

        @Test
        func `Path with only spaces is handled`() throws {

            let path: File.Path = try .init("/tmp/   ")
            #expect(path == "/tmp/   ")
        }

        @Test
        func `Path with unicode characters works`() throws {
            let path = createTempPath() + "-日本語-émoji-🎉"
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try handle.close()

            #expect(File.System.Stat.exists(at: filePath))
        }

        @Test
        func `Path with newline in name is rejected`() throws {

            let pathString = "/tmp/edge-test-with\nnewline-\(Int.random(in: (0..<Int.max)))"
            var didThrow = false
            do throws(File.Path.Error) {
                _ = try File.Path(pathString)
            } catch {
                didThrow = true
            }
            #expect(didThrow)
        }

        @Test
        func `Very long path component`() throws {

            let longName = Swift.String(repeating: "a", count: 255)
            let path = "/tmp/\(longName)"
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try handle.close()

            #expect(File.System.Stat.exists(at: filePath))
        }

        @Test
        func `Path component exceeding 255 bytes fails`() throws {
            let tooLongName = Swift.String(repeating: "a", count: 256)
            let path = "/tmp/\(tooLongName)"

            let filePath = try File.Path(path)

            #expect(throws: (any Swift.Error).self) {
                let handle = try File.Handle.open(
                    filePath,
                    mode: .write,
                    options: [.create, .execClose]
                )
                try handle.close()
            }
        }

        @Test
        func `Handle is valid after open and before close`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )

            let isValidBeforeClose = handle.isValid
            #expect(isValidBeforeClose)

            try handle.close()

        }

        @Test
        func `Close succeeds on freshly opened handle`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )

            try handle.close()

            #expect(File.System.Stat.exists(at: filePath))
        }

        @Test
        func `Handle allows operations before close`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .readWrite,
                options: [.create, .execClose]
            )

            let data: [Byte] = [1, 2, 3, 4, 5]
            try handle.write(data.span)

            _ = try handle.seek(to: 0, from: .start)

            var readBuffer = [Byte](repeating: 0, count: 5)
            let bytesRead = try readBuffer.withUnsafeMutableBytes { ptr in
                try handle.read(into: ptr)
            }

            try handle.close()

            #expect(bytesRead == 5)
            #expect(readBuffer == data)
        }

        @Test
        func `Write to read-only handle fails`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let createHandle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try createHandle.close()

            var handle = try File.Handle.open(filePath, mode: .read)

            let data: [Byte] = [1, 2, 3]
            #expect(throws: (any Swift.Error).self) {
                try handle.write(data.span)
            }

            try handle.close()
        }

        @Test
        func `Seek to negative position fails`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )

            var didThrow = false
            do throws(Kernel.File.Seek.Error) {
                _ = try handle.seek(to: -1, from: .start)
            } catch {
                didThrow = true
            }

            try handle.close()

            #expect(didThrow)
        }

        @Test
        func `Seek past EOF creates sparse file on write`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .readWrite,
                options: [.create, .execClose]
            )

            _ = try handle.seek(to: 1000, from: .start)

            let data: [Byte] = [42]
            try handle.write(data.span)

            try handle.close()

            let info = try File.System.Stat.info(at: filePath)
            #expect(info.size == 1001)
        }

        @Test
        func `Seek from end with zero offset`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )

            let data: [Byte] = [1, 2, 3, 4, 5]
            try handle.write(data.span)

            let pos = try handle.seek(to: 0, from: .end)
            try handle.close()

            #expect(pos == 5)
        }

        @Test
        func `Dangling symlink - stat follows and fails`() throws {
            let linkPath = try File.Path(createTempPath() + ".link")
            let targetPath = try File.Path(createTempPath() + ".target")
            defer {
                cleanupPath(linkPath)
                cleanupPath(targetPath)
            }

            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

            #expect(
                (try? File.System.Stat.info(at: linkPath, followSymlinks: false))?.type
                    == .symbolicLink
            )

            #expect(throws: Kernel.File.Stats.Error.self) {
                _ = try File.System.Stat.info(at: linkPath)
            }

            let info = try File.System.Stat.info(at: linkPath, followSymlinks: false)
            #expect(info.type == .symbolicLink)
        }

        @Test
        func `Symlink cycle detection`() throws {
            let linkA = try File.Path(createTempPath() + ".linkA")
            let linkB = try File.Path(createTempPath() + ".linkB")
            defer {
                cleanupPath(linkA)
                cleanupPath(linkB)
            }

            try File.System.Link.Symbolic.create(at: linkA, pointingTo: linkB)
            try File.System.Link.Symbolic.create(at: linkB, pointingTo: linkA)

            #expect(
                (try? File.System.Stat.info(at: linkA, followSymlinks: false))?.type
                    == .symbolicLink
            )
            #expect(
                (try? File.System.Stat.info(at: linkB, followSymlinks: false))?.type
                    == .symbolicLink
            )

            #expect(throws: Kernel.File.Stats.Error.self) {
                _ = try File.System.Stat.info(at: linkA)
            }
        }

        @Test
        func `Self-referencing symlink`() throws {
            let linkPath = try File.Path(createTempPath() + ".self")
            defer { cleanupPath(linkPath) }

            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: linkPath)

            #expect(
                (try? File.System.Stat.info(at: linkPath, followSymlinks: false))?.type
                    == .symbolicLink
            )

            #expect(throws: Kernel.File.Stats.Error.self) {
                _ = try File.System.Stat.info(at: linkPath)
            }
        }

        @Test
        func `Create directory that already exists fails`() throws {
            let path = try File.Path(createTempPath())
            defer { cleanupPath(path) }

            try File.System.Create.Directory.create(at: path)

            #expect(throws: (any Swift.Error).self) {
                try File.System.Create.Directory.create(at: path)
            }
        }

        @Test
        func `Delete non-empty directory fails without recursive`() throws {
            let dir = try File.Path(createTempPath())
            defer { try? File.System.Delete.delete(at: dir, recursive: true) }

            try File.System.Create.Directory.create(at: dir)

            let filePath = dir / "file.txt"
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try handle.close()

            #expect(throws: (any Swift.Error).self) {
                try File.System.Delete.delete(at: dir)
            }
        }

        @Test
        func `Iterate empty directory yields nothing`() throws {
            let dir = try File.Directory(validating: createTempPath())
            defer { cleanupPath(dir.path) }

            try File.System.Create.Directory.create(at: dir.path)

            var iterator = try File.Directory.Iterator.open(at: dir)

            let entry = try iterator.next()
            iterator.close()

            #expect(entry == nil)
        }

        @Test
        func `Multiple handles to same file`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            var handle1 = try File.Handle.open(
                filePath,
                mode: .readWrite,
                options: [.create, .execClose]
            )
            let data: [Byte] = [1, 2, 3, 4, 5]
            try handle1.write(data.span)

            var handle2 = try File.Handle.open(filePath, mode: .read)

            var buffer = [Byte](repeating: 0, count: 5)
            let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
                try handle2.read(into: ptr)
            }

            try handle1.close()
            try handle2.close()

            #expect(bytesRead == 5)
            #expect(buffer == data)
        }

        @Test
        func `Read with zero-size buffer`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .readWrite,
                options: [.create, .execClose]
            )

            let data: [Byte] = [1, 2, 3]
            try handle.write(data.span)

            _ = try handle.seek(to: 0, from: .start)

            var emptyBuffer: [Byte] = []
            let bytesRead = try emptyBuffer.withUnsafeMutableBytes { ptr in
                try handle.read(into: ptr)
            }

            try handle.close()

            #expect(bytesRead == 0)
        }

        @Test
        func `Multiple sequential reads exhaust file`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            var handle = try File.Handle.open(
                filePath,
                mode: .readWrite,
                options: [.create, .execClose]
            )

            let data: [Byte] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            try handle.write(data.span)

            _ = try handle.seek(to: 0, from: .start)

            var allRead: [Byte] = []
            var buffer = [Byte](repeating: 0, count: 3)

            while true {
                let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
                    try handle.read(into: ptr)
                }
                if bytesRead == 0 { break }
                allRead.append(contentsOf: buffer[..<bytesRead])
            }

            try handle.close()

            #expect(allRead == data)
        }

        #if !os(Windows)
            @Test
            func `Open file without read permission fails`() throws {

                #if canImport(Glibc)
                    if geteuid() == 0 {

                        return
                    }
                #endif

                let path = createTempPath()
                defer { cleanup(path) }

                let filePath = try File.Path(path)

                let handle = try File.Handle.open(
                    filePath,
                    mode: .write,
                    options: [.create, .execClose]
                )
                try handle.close()

                chmod(path, 0o000)
                defer { chmod(path, 0o644) }

                #expect(throws: Kernel.File.Open.Error.self) {
                    _ = try File.Handle.open(filePath, mode: .read)
                }
            }
        #endif

        @Test
        func `Write to /dev/null succeeds`() throws {
            #if !os(Windows)
                let devNull = "/dev/null"
                let path = try File.Path(devNull)
                var handle = try File.Handle.open(path, mode: .write)

                let data: [Byte] = [1, 2, 3, 4, 5]
                try handle.write(data.span)
                try handle.close()

            #endif
        }

        @Test
        func `Copy file to itself fails`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let handle = try File.Handle.open(
                filePath,
                mode: .write,
                options: [.create, .execClose]
            )
            try handle.close()

            #expect(throws: (any Swift.Error).self) {
                try File.System.Copy.copy(from: filePath, to: filePath)
            }
        }

        @Test
        func `Move file to existing destination fails (safe API)`() throws {
            let src = createTempPath()
            let dst = createTempPath()
            defer {
                cleanup(src)
                cleanup(dst)
            }

            let srcPath = try File.Path(src)
            let dstPath = try File.Path(dst)

            var srcHandle = try File.Handle.open(
                srcPath,
                mode: .write,
                options: [.create, .execClose]
            )
            let srcData: [Byte] = [1, 2, 3]
            try srcHandle.write(srcData.span)
            try srcHandle.close()

            var dstHandle = try File.Handle.open(
                dstPath,
                mode: .write,
                options: [.create, .execClose]
            )
            let dstData: [Byte] = [4, 5, 6, 7, 8]
            try dstHandle.write(dstData.span)
            try dstHandle.close()

            var didThrow = false
            do throws(File.System.Move.Error) {
                try File.System.Move.move(from: srcPath, to: dstPath)
            } catch {
                didThrow = true
            }

            #expect(didThrow)

            #expect(File.System.Stat.exists(at: srcPath))
            #expect(File.System.Stat.exists(at: dstPath))
        }

        @Test
        func `Rapid open-write-close cycles`() throws {
            let path = createTempPath()
            defer { cleanup(path) }

            let filePath = try File.Path(path)

            for i in 0..<100 {
                var handle = try File.Handle.open(
                    filePath,
                    mode: .write,
                    options: [.create, .truncate, .execClose]
                )
                let data: [Byte] = [Byte(UInt8(i & 0xFF))]
                try handle.write(data.span)
                try handle.close()
            }

            let info = try File.System.Stat.info(at: filePath)
            #expect(info.size == 1)
        }

        @Test
        func `Rapid create-delete cycles`() throws {
            let basePath = createTempPath()

            for i in 0..<50 {
                let path: File.Path = try .init("\(basePath)-\(i)")
                let handle = try File.Handle.open(
                    path,
                    mode: .write,
                    options: [.create, .execClose]
                )
                try handle.close()
                try File.System.Delete.delete(at: path)
            }

        }

    }
#endif
