//
//  File.System.Move Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Move {
    #TestSuites
}

extension File.System.Move.Test.Unit {

    // MARK: - Basic Move

    @Test("Move file to new location")
    func moveFileToNewLocation() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

            let originalData = try File.System.Read.Full.read(from: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(originalData == destData)
        }
    }

    @Test("Move removes source file")
    func moveRemovesSourceFile() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            // Source should no longer exist
            #expect(!File.System.Stat.exists(at: sourcePath))
        }
    }

    @Test("Move empty file")
    func moveEmptyFile() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([UInt8]().span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(destData.isEmpty)
        }
    }

    @Test("Rename file in same directory")
    func renameFileInSameDirectory() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "renamed.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            #expect(!File.System.Stat.exists(at: sourcePath))
            #expect(File.System.Stat.exists(at: destPath))
        }
    }

    // MARK: - Options

    @Test("Move with overwrite option")
    func moveWithOverwriteOption() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Move.Options(overwrite: true)
            try File.System.Move.move(from: sourcePath, to: destPath, options: options)

            let destData = try File.System.Read.Full.read(from: destPath)
            #expect(destData == [1, 2, 3])
        }
    }

    @Test("Move without overwrite throws when destination exists")
    func moveWithoutOverwriteThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Move.Options(overwrite: false)
            #expect(throws: File.System.Move.Error.self) {
                try File.System.Move.move(from: sourcePath, to: destPath, options: options)
            }
        }
    }

    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.System.Move.Options()
        #expect(options.overwrite == false)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
        let options = File.System.Move.Options(overwrite: true)
        #expect(options.overwrite == true)
    }

    // MARK: - Error Cases

    @Test("Move non-existent source throws sourceNotFound")
    func moveNonExistentSourceThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "non-existent.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            #expect(throws: File.System.Move.Error.self) {
                try File.System.Move.move(from: sourcePath, to: destPath)
            }
        }
    }

    @Test("Move to existing file without overwrite throws destinationExists")
    func moveToExistingFileThrows() throws {
        try File.Directory.temporary { dir in
            let sourcePath = File.Path(dir.path, appending: "source.bin")
            let destPath = File.Path(dir.path, appending: "dest.bin")

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99].span, to: destPath)

            #expect(throws: File.System.Move.Error.destinationExists(destPath)) {
                try File.System.Move.move(from: sourcePath, to: destPath)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("sourceNotFound error description")
    func sourceNotFoundErrorDescription() throws {
        let path = File.Path("/tmp/missing")
        let error = File.System.Move.Error.sourceNotFound(path)
        #expect(error.description.contains("Source not found"))
    }

    @Test("destinationExists error description")
    func destinationExistsErrorDescription() throws {
        let path = File.Path("/tmp/existing")
        let error = File.System.Move.Error.destinationExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() throws {
        let path = File.Path("/root/secret")
        let error = File.System.Move.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("moveFailed error description")
    func moveFailedErrorDescription() {
        let error = File.System.Move.Error.moveFailed(errno: 5, message: "I/O error")
        #expect(error.description.contains("Move failed"))
        #expect(error.description.contains("I/O error"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() throws {
        let path1 = File.Path("/tmp/a")
        let path2 = File.Path("/tmp/a")

        #expect(
            File.System.Move.Error.sourceNotFound(path1)
                == File.System.Move.Error.sourceNotFound(path2)
        )
        #expect(
            File.System.Move.Error.destinationExists(path1)
                == File.System.Move.Error.destinationExists(path2)
        )
    }
}
