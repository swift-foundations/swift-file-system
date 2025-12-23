//
//  File.System.Link.Symbolic Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing
import File_System_Test_Support

@testable import File_System_Primitives

extension File.System.Link.Symbolic {
    #TestSuites
}

extension File.System.Link.Symbolic.Test.Unit {

    // MARK: - Create Symlink

    @Test("Create symlink to file")
    func createSymlinkToFile() throws {
        try File.Directory.temporary { dir in
            let targetPath = File.Path(dir.path, appending: "target.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

            let linkPath = File.Path(dir.path, appending: "link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

            // Verify symlink exists
            #expect(File.System.Stat.exists(at: linkPath))

            // Verify it's a symlink using lstatInfo
            let info = try File.System.Stat.lstatInfo(at: linkPath)
            #expect(info.type == .symbolicLink)
        }
    }

    @Test("Create symlink to directory")
    func createSymlinkToDirectory() throws {
        try File.Directory.temporary { dir in
            let targetPath = File.Path(dir.path, appending: "target-dir")
            try File.System.Create.Directory.create(at: targetPath)

            let linkPath = File.Path(dir.path, appending: "link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

            let info = try File.System.Stat.lstatInfo(at: linkPath)
            #expect(info.type == .symbolicLink)
        }
    }

    @Test("Symlink points to correct target")
    func symlinkPointsToCorrectTarget() throws {
        try File.Directory.temporary { dir in
            let targetPath = File.Path(dir.path, appending: "target.bin")
            try File.System.Write.Atomic.write([10, 20, 30].span, to: targetPath)

            let linkPath = File.Path(dir.path, appending: "link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

            // Read through symlink
            let data = try File.System.Read.Full.read(from: linkPath)
            #expect(data == [10, 20, 30])
        }
    }

    @Test("Create symlink to non-existent target succeeds")
    func createSymlinkToNonExistentTarget() throws {
        try File.Directory.temporary { dir in
            let targetPath = File.Path(dir.path, appending: "non-existent-target")
            let linkPath = File.Path(dir.path, appending: "link")

            // Creating symlink to non-existent target should succeed
            // (it's a dangling symlink, but that's allowed)
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)

            let info = try File.System.Stat.lstatInfo(at: linkPath)
            #expect(info.type == .symbolicLink)
        }
    }

    // MARK: - Error Cases

    @Test("Create symlink at existing path throws alreadyExists")
    func createSymlinkAtExistingPathThrows() throws {
        try File.Directory.temporary { dir in
            let targetPath = File.Path(dir.path, appending: "target.bin")
            try File.System.Write.Atomic.write([1, 2, 3].span, to: targetPath)

            let linkPath = File.Path(dir.path, appending: "existing.bin")
            try File.System.Write.Atomic.write([4, 5, 6].span, to: linkPath)

            #expect(throws: File.System.Link.Symbolic.Error.alreadyExists(linkPath)) {
                try File.System.Link.Symbolic.create(at: linkPath, pointingTo: targetPath)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("targetNotFound error description")
    func targetNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.System.Link.Symbolic.Error.targetNotFound(path)
        #expect(error.description.contains("Target not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
        let error = File.System.Link.Symbolic.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("alreadyExists error description")
    func alreadyExistsErrorDescription() throws {
        let path = File.Path("/tmp/existing")
        let error = File.System.Link.Symbolic.Error.alreadyExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("linkFailed error description")
    func linkFailedErrorDescription() {
        let error = File.System.Link.Symbolic.Error.linkFailed(
            errno: 22,
            message: "Invalid argument"
        )
        #expect(error.description.contains("Symlink creation failed"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = File.Path("/tmp/a")
        let path2 = File.Path("/tmp/a")

        #expect(
            File.System.Link.Symbolic.Error.alreadyExists(path1)
                == File.System.Link.Symbolic.Error.alreadyExists(path2)
        )
        #expect(
            File.System.Link.Symbolic.Error.targetNotFound(path1)
                == File.System.Link.Symbolic.Error.targetNotFound(path2)
        )
    }
}
