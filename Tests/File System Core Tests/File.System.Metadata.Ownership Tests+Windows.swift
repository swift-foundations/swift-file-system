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
        func `Set ownership to a different identity throws on Windows`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                // Kernel.File.Chown's conditional no-op succeeds only when the
                // requested ownership matches the synthesized (0, 0) identity;
                // anything else throws rather than silently pretending to succeed.
                let ownership = File.System.Metadata.Ownership(uid: 1000, gid: 1000)
                #expect(throws: File.System.Metadata.Ownership.Error.self) {
                    try File.System.Metadata.Ownership.set(ownership, at: filePath)
                }

                // The on-disk (synthesized) ownership is unaffected.
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
        func `Set ownership on Windows succeeds only for the synthesized identity`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                // Only (0, 0) matches the synthesized identity Windows reports;
                // every other combination should throw rather than succeed.
                let testCases: [(uid: UInt32, gid: UInt32, shouldSucceed: Bool)] = [
                    (1000, 1000, false),
                    (0, 0, true),
                    (501, 20, false),
                    (65534, 65534, false),
                ]

                for (uid, gid, shouldSucceed) in testCases {
                    let ownership = File.System.Metadata.Ownership(
                        uid: Kernel.User.ID(_unchecked: uid),
                        gid: Kernel.Group.ID(_unchecked: gid)
                    )
                    if shouldSucceed {
                        try File.System.Metadata.Ownership.set(ownership, at: filePath)
                    } else {
                        #expect(throws: File.System.Metadata.Ownership.Error.self) {
                            try File.System.Metadata.Ownership.set(ownership, at: filePath)
                        }
                    }

                    // The on-disk (synthesized) ownership is unaffected either way.
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
