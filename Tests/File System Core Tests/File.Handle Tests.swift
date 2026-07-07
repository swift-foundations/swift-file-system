//
//  File.Handle Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

extension File.Handle {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.Handle.Test.Unit {
    // MARK: - Opening

    @Test
    func `Open file for reading`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .read)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .read)
            try handle.close()
        }
    }

    @Test
    func `Open file for writing`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .write)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .write)
            try handle.close()
        }
    }

    @Test
    func `Open file for read/write`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .readWrite)
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .readWrite)
            try handle.close()
        }
    }

    @Test
    func `Open file for append`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            let handle = try File.Handle.open(filePath, mode: .write, options: [.append])
            let isValid = handle.isValid
            let mode = handle.mode
            #expect(isValid)
            #expect(mode == .write)
            try handle.close()
        }
    }

    @Test
    func `Open with create option`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"

            let handle = try File.Handle.open(filePath, mode: .write, options: [.create])
            let isValid = handle.isValid
            #expect(isValid)
            #expect(File.System.Stat.exists(at: filePath))
            try handle.close()
        }
    }

    @Test
    func `Open non-existing file throws error`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "non-existing.txt"

            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try File.Handle.open(filePath, mode: .read)
            }
        }
    }

    // MARK: - Reading

    @Test
    func `Read bytes from file`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [10, 20, 30, 40, 50]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)
            let readData = try handle.read(count: 5)
            #expect(readData == content)
            try handle.close()
        }
    }

    @Test
    func `Read partial bytes`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let firstPart = try handle.read(count: 5)
            #expect(firstPart == [1, 2, 3, 4, 5])

            let secondPart = try handle.read(count: 5)
            #expect(secondPart == [6, 7, 8, 9, 10])
            try handle.close()
        }
    }

    @Test
    func `Read at EOF returns empty`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            _ = try handle.read(count: 3)  // Read all
            let atEOF = try handle.read(count: 10)
            #expect(atEOF.isEmpty)
            try handle.close()
        }
    }

    @Test
    func `Read more than available returns available`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let readData = try handle.read(count: 100)
            #expect(readData == content)
            try handle.close()
        }
    }

    // MARK: - Writing

    @Test
    func `Write bytes to file`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write([Byte]().span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

            let data: [Byte] = [100, 101, 102, 103, 104]
            try handle.write(data.span)
            try handle.close()

            let readBack = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readBack == data)
        }
    }

    @Test
    func `Write empty data`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write([1, 2, 3].span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write, options: [.truncate])

            let data: [Byte] = []
            try handle.write(data.span)
            try handle.close()

            let readBack = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(readBack.isEmpty)
        }
    }

    // MARK: - Seeking

    @Test
    func `Seek from start`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let newPos = try handle.seek(to: 5, from: .start)
            #expect(newPos == 5)

            let readData = try handle.read(count: 3)
            #expect(readData == [6, 7, 8])
            try handle.close()
        }
    }

    @Test
    func `Seek from current`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            _ = try handle.read(count: 3)  // Position at 3
            let newPos = try handle.seek(to: 2, from: .current)  // Now at 5
            #expect(newPos == 5)

            let readData = try handle.read(count: 1)
            #expect(readData == [6])
            try handle.close()
        }
    }

    @Test
    func `Seek from end`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let newPos = try handle.seek(to: -3, from: .end)
            #expect(newPos == 7)

            let readData = try handle.read(count: 3)
            #expect(readData == [8, 9, 10])
            try handle.close()
        }
    }

    @Test
    func `Get current position`() throws {
        try File.Directory.temporary { dir in
            let content: [Byte] = [1, 2, 3, 4, 5]
            let filePath = dir.path / "test.bin"
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .read)

            let pos1 = try handle.seek(to: 0, from: .current)
            #expect(pos1 == 0)
            _ = try handle.read(count: 3)
            let pos2 = try handle.seek(to: 0, from: .current)
            #expect(pos2 == 3)
            try handle.close()
        }
    }

    // MARK: - Sync

    @Test
    func `Sync flushes to disk`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            var handle = try File.Handle.open(filePath, mode: .write, options: [.create])

            let data: [Byte] = [1, 2, 3]
            try handle.write(data.span)
            try handle.sync()
            try handle.close()

            // File should exist and have content
            #expect(File.System.Stat.exists(at: filePath))
        }
    }

}

// MARK: - Positional Write Tests (pwrite)

extension File.Handle.Test.Unit {
    @Test
    func `pwrite writes at absolute offset`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwrite_test.bin"

            // Create file and write initial content
            var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .truncate])

            // Write "AAAA" at offset 0
            let bytes1: [Byte] = [0x41, 0x41, 0x41, 0x41]
            try bytes1.withUnsafeBytes { buffer in
                let written = try handle.pwrite(buffer, at: 0)
                #expect(written == 4)
            }

            // Write "BBBB" at offset 4
            let bytes2: [Byte] = [0x42, 0x42, 0x42, 0x42]
            try bytes2.withUnsafeBytes { buffer in
                let written = try handle.pwrite(buffer, at: 4)
                #expect(written == 4)
            }

            try handle.close()

            // Verify content: should be "AAAABBBB"
            let content = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(content == [0x41, 0x41, 0x41, 0x41, 0x42, 0x42, 0x42, 0x42])
        }
    }

    @Test
    func `pwrite does not advance file position`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwrite_pos_test.bin"

            // Create a file with some initial content for seeking
            let initial: [Byte] = [0, 0, 0, 0, 0, 0, 0, 0]
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .readWrite)

            // Get initial position
            let pos1 = try handle.seek(to: 0, from: .current)
            #expect(pos1 == 0)

            // Write at offset 4 using pwrite
            let bytes: [Byte] = [0xFF, 0xFF]
            try bytes.withUnsafeBytes { buffer in
                _ = try handle.pwrite(buffer, at: 4)
            }

            // Position should still be 0 (not advanced)
            let pos2 = try handle.seek(to: 0, from: .current)
            #expect(pos2 == 0)

            try handle.close()
        }
    }

    @Test
    func `pwrite overwrites at specified offset`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwrite_overwrite.bin"

            // Create file with "XXXXXXXX"
            let initial: [Byte] = [0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58]
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write)

            // Overwrite bytes 2-5 with "YYYY"
            let bytes: [Byte] = [0x59, 0x59, 0x59, 0x59]
            try bytes.withUnsafeBytes { buffer in
                _ = try handle.pwrite(buffer, at: 2)
            }

            try handle.close()

            // Should be "XXYYYYXX"
            let content = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(content == [0x58, 0x58, 0x59, 0x59, 0x59, 0x59, 0x58, 0x58])
        }
    }

    @Test
    func `pwrite with empty buffer returns 0`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwrite_empty.bin"

            var handle = try File.Handle.open(filePath, mode: .write, options: [.create])

            let empty: [Byte] = []
            try empty.withUnsafeBytes { buffer in
                let written = try handle.pwrite(buffer, at: 0)
                #expect(written == 0)
            }

            try handle.close()
        }
    }

    @Test
    func `pwriteAll writes all bytes`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwriteall_test.bin"

            var handle = try File.Handle.open(filePath, mode: .write, options: [.create, .truncate])

            // Write 10KB of data using pwriteAll
            let data = [Byte](repeating: 0xAB, count: 10_000)
            try data.withUnsafeBytes { buffer in
                try handle.pwriteAll(buffer, at: 0)
            }

            try handle.close()

            // Verify all bytes written
            let content = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(content.count == 10_000)
            #expect(content.allSatisfy { $0 == 0xAB })
        }
    }

    @Test
    func `pwriteAll at non-zero offset`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "pwriteall_offset.bin"

            // Create file with zeros
            let initial = [Byte](repeating: 0, count: 100)
            try File.System.Write.Atomic.write(initial.span, to: filePath)

            var handle = try File.Handle.open(filePath, mode: .write)

            // Write at offset 50
            let data: [Byte] = [1, 2, 3, 4, 5]
            try data.withUnsafeBytes { buffer in
                try handle.pwriteAll(buffer, at: 50)
            }

            try handle.close()

            // Verify
            let content = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(content[50] == 1)
            #expect(content[51] == 2)
            #expect(content[52] == 3)
            #expect(content[53] == 4)
            #expect(content[54] == 5)
        }
    }

}
