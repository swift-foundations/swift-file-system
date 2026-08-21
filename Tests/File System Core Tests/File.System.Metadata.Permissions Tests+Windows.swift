import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

#if os(Windows)
    extension File.System.Metadata.Permissions.Test.Unit {

        @Test
        func `Get permissions on Windows synthesizes 0o644 for a regular writable file`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                let perms = try File.System.Metadata.Permissions(at: filePath)
                #expect(perms == .defaultFile)
            }
        }

        @Test
        func `Get permissions on Windows for a directory includes execute bits`() throws {
            try File.Directory.temporary { dir in
                let subdirPath = dir.path / "subdir"
                try File.System.Create.Directory.create(at: subdirPath)

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

                let newPerms: File.System.Metadata.Permissions = [.ownerRead]
                try File.System.Metadata.Permissions.set(newPerms, at: filePath)

                let readBack = try File.System.Metadata.Permissions(at: filePath)
                #expect(readBack == .defaultFile)
            }
        }

        @Test
        func `Permissions roundtrip on Windows preserves default`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                try File.System.Write.Atomic.write([], to: filePath)

                let testCases: [File.System.Metadata.Permissions] = [
                    [.ownerRead, .ownerWrite, .ownerExecute],
                    [.groupRead],
                    [.otherRead, .otherWrite],
                    .executable,
                    .defaultDirectory,
                ]

                for testPerms in testCases {
                    try File.System.Metadata.Permissions.set(testPerms, at: filePath)

                    let readBack = try File.System.Metadata.Permissions(at: filePath)
                    #expect(readBack == .defaultFile)
                }
            }
        }

        @Test
        func `File is readable after creation`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "readable.txt"
                let testData: [Byte] = [1, 2, 3, 4, 5]
                try File.System.Write.Atomic.write(testData, to: filePath)

                let readData = try File.System.Read.Full.read(from: filePath) {
                    $0.withUnsafeBytes { unsafe $0.map(Byte.init) }
                }
                #expect(readData == testData)
            }
        }

    }
#endif
