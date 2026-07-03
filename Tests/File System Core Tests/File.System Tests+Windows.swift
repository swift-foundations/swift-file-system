//
//  File.System Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for core file system operations.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)

    import WinSDK

    extension File.System.Test.EdgeCase {

        // MARK: - Windows Path Tests

        @Test
        func `Handle Windows drive letter paths`() throws {
            // Use GetWindowsDirectoryW to get the system Windows directory
            // This avoids Foundation dependency and works across Windows installations
            var buffer = [UInt16](repeating: 0, count: Int(MAX_PATH))
            let length = GetWindowsDirectoryW(&buffer, DWORD(buffer.count))

            #expect(length > 0)

            let windowsPath = Swift.String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
            let path = try File.Path(windowsPath)

            #expect(File.System.Stat.exists(at: path))
        }

        @Test
        func `Handle Windows UNC-style paths in temp`() throws {
            try File.Directory.temporary { dir in
                // Temp directory should be accessible
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))
            }
        }

        // MARK: - Windows File Operations

        @Test
        func `Create and read file with Windows line endings`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "crlf.txt"
                // Windows-style line endings: CRLF
                let content: [Byte] = Array("Hello\r\nWorld\r\n".utf8).map(Byte.init)

                try File.System.Write.Atomic.write(content, to: filePath)

                let readBack = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readBack == content)
            }
        }

        @Test
        func `Handle long file names on Windows`() throws {
            try File.Directory.temporary { dir in
                // Use 100 chars to stay well within MAX_PATH (260) when combined
                // with temp directory path (~60 chars) and atomic write temp suffix
                let longName = Swift.String(repeating: "a", count: 100) + ".txt"
                let filePath = dir.path / "\(longName)"

                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))

                let readBack = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readBack == [1, 2, 3])
            }
        }

        @Test
        func `Handle files with spaces in name`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "file with spaces.txt"

                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))

                let readBack = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readBack == [1, 2, 3])
            }
        }

        // MARK: - Windows-Specific Features

        @Test
        func `File stat returns valid info on Windows`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let testData: [Byte] = [1, 2, 3, 4, 5]
                try File.System.Write.Atomic.write(testData, to: filePath)

                let info = try File.System.Stat.info(at: filePath)

                #expect(info.type == .regular)
                #expect(info.size == 5)  // testData.count
                // Windows returns device ID and file index
                #expect(info.device > 0 || info.inode > 0)
            }
        }

        @Test
        func `Directory stat returns correct type`() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let info = try File.System.Stat.info(at: subPath)
                #expect(info.type == .directory)
            }
        }

        @Test
        func `File deletion works on Windows`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "deleteme.txt"
                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)

                #expect(File.System.Stat.exists(at: filePath))

                try File.System.Delete.delete(at: filePath)

                #expect(!File.System.Stat.exists(at: filePath))
            }
        }

        @Test
        func `Directory deletion works on Windows`() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "deletedir"
                try File.System.Create.Directory.create(at: subPath)

                #expect(File.System.Stat.exists(at: subPath))

                try File.System.Delete.delete(at: subPath)

                #expect(!File.System.Stat.exists(at: subPath))
            }
        }
    }

#endif
