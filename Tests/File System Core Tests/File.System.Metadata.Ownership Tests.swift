import File_System_Test_Support
import Kernel
import Tagged_Standard_Library_Integration
import Testing

@testable import File_System_Core

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

extension File.System.Metadata.Ownership {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Metadata.Ownership.Test.Unit {

    @Test
    func `Ownership initialization`() {
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)

        #expect(ownership.uid == 501)
        #expect(ownership.gid == 20)
    }

    #if os(macOS) || os(Linux)
        @Test
        func `Get ownership of file`() throws {
            try File.Directory.temporary { dir in
                let filePath = dir.path / "test.txt"
                let empty: [Byte] = []
                try File.System.Write.Atomic.write(empty.span, to: filePath)

                let ownership = try File.System.Metadata.Ownership(at: filePath)

                #expect(ownership.uid.underlying == getuid())

                var statBuf = stat()
                _ = stat(Swift.String(filePath), &statBuf)
                #expect(ownership.gid.underlying == statBuf.st_gid)
            }
        }

        @Test
        func `Get ownership of system file`() throws {

            let filePath = File.Path("/etc/passwd")
            let ownership = try File.System.Metadata.Ownership(at: filePath)

            #expect(ownership.uid == 0)
        }
    #endif

    @Test
    func `Set ownership to same owner succeeds`() throws {
        try File.Directory.temporary { dir in
            let filePath = dir.path / "test.txt"
            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty.span, to: filePath)

            let currentOwnership = try File.System.Metadata.Ownership(at: filePath)

            try File.System.Metadata.Ownership.set(currentOwnership, at: filePath)

            let afterSet = try File.System.Metadata.Ownership(at: filePath)
            #expect(afterSet.uid == currentOwnership.uid)
            #expect(afterSet.gid == currentOwnership.gid)
        }
    }

    @Test
    func `Get ownership of non-existent file throws error with isNotFound`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "non-existent.txt"

            do throws(File.System.Metadata.Ownership.Error) {
                _ = try File.System.Metadata.Ownership(at: path)
                Issue.record("Expected error for non-existent file")
            } catch {
                #expect(error.isNotFound)
            }
        }
    }

    #if !os(Windows)

        @Test
        func `Set ownership of non-existent file throws error with isNotFound`() throws {
            try File.Directory.temporary { dir in
                let path = dir.path / "non-existent.txt"

                let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

                do throws(File.System.Metadata.Ownership.Error) {
                    try File.System.Metadata.Ownership.set(ownership, at: path)
                    Issue.record("Expected error for non-existent file")
                } catch {
                    #expect(error.isNotFound)
                }
            }
        }
    #endif

    @Test
    func `isNotFound semantic accessor for stat error`() {

        let error = File.System.Metadata.Ownership.Error.chown(.path(.notFound))
        #expect(error.isNotFound)
        #expect(!error.isPermissionDenied)
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Metadata.Ownership.Error.chown(.permission(.denied))
        #expect(error.isPermissionDenied)
        #expect(!error.isNotFound)
    }

    @Test
    func `isReadOnly semantic accessor`() {
        let error = File.System.Metadata.Ownership.Error.chown(.permission(.readOnlyFilesystem))
        #expect(error.isReadOnly)
        #expect(!error.isPermissionDenied)
    }

    @Test
    func `Ownership is equatable`() {
        let ownership1 = File.System.Metadata.Ownership(uid: 501, gid: 20)
        let ownership2 = File.System.Metadata.Ownership(uid: 501, gid: 20)
        let ownership3 = File.System.Metadata.Ownership(uid: 502, gid: 20)

        #expect(ownership1 == ownership2)
        #expect(ownership1 != ownership3)
    }

    @Test
    func `Ownership is sendable`() async {
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)

        await Task {
            #expect(ownership.uid == 501)
            #expect(ownership.gid == 20)
        }.value
    }
}
