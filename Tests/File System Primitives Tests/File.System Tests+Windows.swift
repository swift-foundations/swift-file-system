//
//  File.System Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for core file system operations.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if os(Windows)

    import WinSDK

    extension File.System.Test.EdgeCase {

        // MARK: - Windows Path Tests

        @Test("Handle Windows drive letter paths")
        func handleWindowsDrivePaths() throws {
            // Use GetWindowsDirectoryW to get the system Windows directory
            // This avoids Foundation dependency and works across Windows installations
            var buffer = [UInt16](repeating: 0, count: Int(MAX_PATH))
            let length = GetWindowsDirectoryW(&buffer, DWORD(buffer.count))

            #expect(length > 0)

            let windowsPath = String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
            let path = try File.Path(windowsPath)

            #expect(File.System.Stat.exists(at: path))
        }

        @Test("Handle Windows UNC-style paths in temp")
        func handleWindowsTempPaths() throws {
            try File.Directory.temporary { dir in
                // Temp directory should be accessible
                let filePath = File.Path(dir.path, appending: "test.txt")
                try File.System.Write.Atomic.write([], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))
            }
        }

        // MARK: - Windows File Operations

        @Test("Create and read file with Windows line endings")
        func windowsLineEndings() throws {
            try File.Directory.temporary { dir in
                let filePath = File.Path(dir.path, appending: "crlf.txt")
                // Windows-style line endings: CRLF
                let content: [UInt8] = Array("Hello\r\nWorld\r\n".utf8)

                try File.System.Write.Atomic.write(content, to: filePath)

                let readBack = try File.System.Read.Full.read(from: filePath)
                #expect(readBack == content)
            }
        }

        @Test("Handle long file names on Windows")
        func handleLongFileNames() throws {
            try File.Directory.temporary { dir in
                // Use 100 chars to stay well within MAX_PATH (260) when combined
                // with temp directory path (~60 chars) and atomic write temp suffix
                let longName = String(repeating: "a", count: 100) + ".txt"
                let filePath = File.Path(dir.path, appending: longName)

                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))

                let readBack = try File.System.Read.Full.read(from: filePath)
                #expect(readBack == [1, 2, 3])
            }
        }

        @Test("Handle files with spaces in name")
        func handleSpacesInFileName() throws {
            try File.Directory.temporary { dir in
                let filePath = File.Path(dir.path, appending: "file with spaces.txt")

                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)
                #expect(File.System.Stat.exists(at: filePath))

                let readBack = try File.System.Read.Full.read(from: filePath)
                #expect(readBack == [1, 2, 3])
            }
        }

        // MARK: - Windows-Specific Features

        @Test("File stat returns valid info on Windows")
        func statReturnsValidInfo() throws {
            try File.Directory.temporary { dir in
                let filePath = File.Path(dir.path, appending: "test.txt")
                let testData: [UInt8] = [1, 2, 3, 4, 5]
                try File.System.Write.Atomic.write(testData, to: filePath)

                let info = try File.System.Stat.info(at: filePath)

                #expect(info.type == .regular)
                #expect(info.size == Int64(testData.count))
                // Windows returns device ID and file index
                #expect(info.deviceId > 0 || info.inode > 0)
            }
        }

        @Test("Directory stat returns correct type")
        func directoryStatReturnsCorrectType() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                let info = try File.System.Stat.info(at: subPath)
                #expect(info.type == .directory)
            }
        }

        @Test("File deletion works on Windows")
        func fileDeletionWorks() throws {
            try File.Directory.temporary { dir in
                let filePath = File.Path(dir.path, appending: "deleteme.txt")
                try File.System.Write.Atomic.write([1, 2, 3], to: filePath)

                #expect(File.System.Stat.exists(at: filePath))

                try File.System.Delete.delete(at: filePath)

                #expect(!File.System.Stat.exists(at: filePath))
            }
        }

        @Test("Directory deletion works on Windows")
        func directoryDeletionWorks() throws {
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
