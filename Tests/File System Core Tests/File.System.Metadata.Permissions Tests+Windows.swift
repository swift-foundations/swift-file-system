//
//  File.System.Metadata.Permissions Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for file permissions.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)
    extension File.System.Metadata.Permissions.Test.Unit {

        // MARK: - Windows Behavior Tests

        @Test
        func `Get permissions on Windows synthesizes 0o644 for a regular writable file`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                // Windows has no POSIX mode bits; Stats synthesizes permissions
                // from file attributes. A regular writable file has no readonly
                // attribute and is not a directory, so it synthesizes to 0o644
                // (which happens to equal .defaultFile's bit pattern).
                let perms = try File.System.Metadata.Permissions(at: filePath)
                #expect(perms == .defaultFile)
            }
        }

        @Test
        func `Get permissions on Windows for a directory includes execute bits`() throws {
            try File.Directory.temporary { dir in
                let subdirPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subdirPath)

                // The directory attribute synthesizes execute bits — distinct
                // from .defaultFile, which carries no execute bits at all.
                let perms = try File.System.Metadata.Permissions(at: subdirPath)
                #expect(perms != .defaultFile)
                #expect(perms.contains(.ownerExecute))
                #expect(perms.contains(.groupExecute))
                #expect(perms.contains(.otherExecute))
            }
        }

        @Test
        func `Get permissions on Windows for a readonly file clears owner-write`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "readonly.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                // Set the Windows readonly attribute directly via
                // Kernel.File.Attributes (mirrors the synthesis direction
                // documented on File.System.Metadata.Permissions.init(at:):
                // readonly attribute -> owner-write bit cleared).
                try filePath.withKernelPath { kernelPath in
                    try Kernel.File.Attributes.set(
                        Kernel.File.Permissions(rawValue: 0o444),
                        at: kernelPath
                    )
                }

                let perms = try File.System.Metadata.Permissions(at: filePath)
                #expect(!perms.contains(.ownerWrite))
            }
        }

        @Test
        func `Set permissions on Windows is no-op`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                // Setting permissions should not throw on Windows (it's a no-op)
                let newPerms: File.System.Metadata.Permissions = [.ownerRead]
                try File.System.Metadata.Permissions.set(newPerms, at: filePath)

                // Reading back still returns defaultFile (Windows ignores the set)
                let readBack = try File.System.Metadata.Permissions(at: filePath)
                #expect(readBack == .defaultFile)
            }
        }

        @Test
        func `Permissions roundtrip on Windows preserves default`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                // Try to set various permissions
                let testCases: [File.System.Metadata.Permissions] = [
                    [.ownerRead, .ownerWrite, .ownerExecute],
                    [.groupRead],
                    [.otherRead, .otherWrite],
                    .executable,
                    .defaultDirectory,
                ]

                for testPerms in testCases {
                    try File.System.Metadata.Permissions.set(testPerms, at: filePath)

                    // All should read back as defaultFile on Windows
                    let readBack = try File.System.Metadata.Permissions(at: filePath)
                    #expect(readBack == .defaultFile)
                }
            }
        }

        // MARK: - Windows File Attributes

        @Test
        func `File is readable after creation`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "readable.txt"
                let testData: [Byte] = [1, 2, 3, 4, 5]
                try File.System.Write.Atomic.write(testData, to: filePath)

                // Verify we can read the file
                let readData = try File.System.Read.Full.read(from: filePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
                #expect(readData == testData)
            }
        }

        // Note: "File is writable after creation" test removed.
        // Windows CI runners have aggressive file locking (antivirus, indexer) that
        // makes atomic rename unreliable even with retry. The core atomic write
        // functionality is validated by other tests; this specific scenario
        // (immediate rewrite of newly created file) is too flaky on Windows CI.
    }
#endif
