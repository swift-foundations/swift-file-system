//
//  File.System.Metadata.Ownership Tests+Windows.swift
//  swift-file-system
//
//  Windows-specific tests for file ownership.
//

import File_System_Test_Support
import Kernel
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import File_System_Core

#if os(Windows)
    extension File.System.Metadata.Ownership.Test.Unit {

        // MARK: - Windows Behavior Tests

        @Test
        func `Get ownership on Windows returns zero values`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                // Windows doesn't expose uid/gid, so init(at:) returns zeros
                let ownership = try File.System.Metadata.Ownership(at: filePath)
                #expect(ownership.uid == 0)
                #expect(ownership.gid == 0)
            }
        }

        @Test
        func `Set ownership on Windows is no-op`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                // Setting ownership should not throw on Windows (it's a no-op)
                let ownership = File.System.Metadata.Ownership(uid: 1000, gid: 1000)
                try File.System.Metadata.Ownership.set(ownership, at: filePath)

                // Reading back still returns zeros (Windows ignores the set)
                let readBack = try File.System.Metadata.Ownership(at: filePath)
                #expect(readBack.uid == 0)
                #expect(readBack.gid == 0)
            }
        }

        @Test
        func `Set ownership to same owner succeeds on Windows`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                let currentOwnership = try File.System.Metadata.Ownership(at: filePath)

                // Setting to same ownership (zeros) should succeed
                try File.System.Metadata.Ownership.set(currentOwnership, at: filePath)

                let afterSet = try File.System.Metadata.Ownership(at: filePath)
                #expect(afterSet.uid == currentOwnership.uid)
                #expect(afterSet.gid == currentOwnership.gid)
            }
        }

        @Test
        func `Ownership roundtrip on Windows preserves zeros`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                // Try to set various ownership values
                let testCases: [(uid: UInt32, gid: UInt32)] = [
                    (1000, 1000),
                    (0, 0),
                    (501, 20),
                    (65534, 65534),
                ]

                for (uid, gid) in testCases {
                    let ownership = File.System.Metadata.Ownership(uid: uid, gid: gid)
                    try File.System.Metadata.Ownership.set(ownership, at: filePath)

                    // All should read back as zeros on Windows
                    let readBack = try File.System.Metadata.Ownership(at: filePath)
                    #expect(readBack.uid == 0)
                    #expect(readBack.gid == 0)
                }
            }
        }

        @Test
        func `Get ownership of directory on Windows`() throws {
            try File.Directory.temporary { dir in
                let subPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subPath)

                // Windows doesn't expose uid/gid for directories either
                let ownership = try File.System.Metadata.Ownership(at: subPath)
                #expect(ownership.uid == 0)
                #expect(ownership.gid == 0)
            }
        }
    }
#endif
