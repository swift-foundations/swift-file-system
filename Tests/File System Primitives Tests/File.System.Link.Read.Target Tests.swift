//
//  File.System.Link.Read.Target Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Link.Read.Target {
    #TestSuites
}

extension File.System.Link.Read.Target.Test.Unit {
    // MARK: - Read Target

    #if !os(Windows)
        // Windows symlink target reading returns the link path instead of the actual target path
        // These tests require POSIX symlink semantics

        @Test("Read target of symlink to file")
        func readTargetOfSymlinkToFile() throws {
            try File.Directory.temporary { dir in
                let targetPath = File.Path(dir.path, appending: "target.bin")
                try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link")
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(target.string == String(targetPath))
            }
        }

        @Test("Read target of symlink to directory")
        func readTargetOfSymlinkToDirectory() throws {
            try File.Directory.temporary { dir in
                let targetPath = File.Path(dir.path, appending: "target-dir")
                try File.System.Create.Directory.create(at: targetPath)

                let linkPath = File.Path(dir.path, appending: "link")
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(target.string == String(targetPath))
            }
        }

        @Test("Read target of dangling symlink")
        func readTargetOfDanglingSymlink() throws {
            try File.Directory.temporary { dir in
                let targetPath = File.Path(dir.path, appending: "non-existent")
                let linkPath = File.Path(dir.path, appending: "link")

                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: targetPath
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(target.string == String(targetPath))
            }
        }

        @Test("Read target of relative symlink")
        func readTargetOfRelativeSymlink() throws {
            try File.Directory.temporary { dir in
                let targetPath = File.Path(dir.path, appending: "target.txt")
                try File.System.Write.Atomic.write([], to: targetPath)

                let linkPath = File.Path(dir.path, appending: "link.txt")
                try File.System.Link.Symbolic.create(
                    at: linkPath,
                    pointingTo: File.Path("target.txt")
                )

                let target = try File.System.Link.Read.Target.target(of: linkPath)
                #expect(target.string == "target.txt")
            }
        }
    #endif

    // MARK: - Error Cases

    @Test("Read target of regular file throws notASymlink")
    func readTargetOfRegularFileThrows() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "file.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: filePath)

            #expect(throws: File.System.Link.Read.Target.Error.notASymlink(filePath)) {
                _ = try File.System.Link.Read.Target.target(of: filePath)
            }
        }
    }

    @Test("Read target of directory throws notASymlink")
    func readTargetOfDirectoryThrows() throws {
        try File.Directory.temporary { dir in
            let dirPath = File.Path(dir.path, appending: "subdir")
            try File.System.Create.Directory.create(at: dirPath)

            #expect(throws: File.System.Link.Read.Target.Error.notASymlink(dirPath)) {
                _ = try File.System.Link.Read.Target.target(of: dirPath)
            }
        }
    }

    @Test("Read target of non-existent path throws pathNotFound")
    func readTargetOfNonExistentPathThrows() throws {
        try File.Directory.temporary { dir in
            let nonExistent = File.Path(dir.path, appending: "non-existent")

            #expect(throws: File.System.Link.Read.Target.Error.pathNotFound(nonExistent)) {
                _ = try File.System.Link.Read.Target.target(of: nonExistent)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("notASymlink error description")
    func notASymlinkErrorDescription() throws {
        let path = File.Path("/tmp/regular")
        let error = File.System.Link.Read.Target.Error.notASymlink(path)
        #expect(error.description.contains("Not a symbolic link"))
    }

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.System.Link.Read.Target.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
        let error = File.System.Link.Read.Target.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("readFailed error description")
    func readFailedErrorDescription() {
        let error = File.System.Link.Read.Target.Error.readFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Read link target failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = File.Path("/tmp/a")
        let path2 = File.Path("/tmp/a")

        #expect(
            File.System.Link.Read.Target.Error.notASymlink(path1)
                == File.System.Link.Read.Target.Error.notASymlink(path2)
        )
        #expect(
            File.System.Link.Read.Target.Error.pathNotFound(path1)
                == File.System.Link.Read.Target.Error.pathNotFound(path2)
        )
    }

}
