//
//  File.System.Move Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Move {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Move.Test.Unit {

    // MARK: - Basic Move

    @Test
    func `Move file to new location`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([10, 20, 30, 40].span, to: sourcePath)

            let originalData = try File.System.Read.Full.read(from: sourcePath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }

            try File.System.Move.move(from: sourcePath, to: destPath)

            #expect(File.System.Stat.exists(at: destPath))

            let destData = try File.System.Read.Full.read(from: destPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(originalData == destData)
        }
    }

    @Test
    func `Move removes source file`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            // Source should no longer exist
            #expect(!File.System.Stat.exists(at: sourcePath))
        }
    }

    @Test
    func `Move empty file`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([Byte]().span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            try File.System.Read.Full.read(from: destPath) { span in
                #expect(span.count == 0)
            }
        }
    }

    @Test
    func `Rename file in same directory`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "renamed.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)

            try File.System.Move.move(from: sourcePath, to: destPath)

            #expect(!File.System.Stat.exists(at: sourcePath))
            #expect(File.System.Stat.exists(at: destPath))
        }
    }

    // MARK: - Options

    @Test
    func `Move with overwrite option`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Move.Options(overwrite: true)
            try File.System.Move.move(from: sourcePath, to: destPath, options: options)

            let destData = try File.System.Read.Full.read(from: destPath) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(destData == [1, 2, 3])
        }
    }

    @Test
    func `Move without overwrite throws when destination exists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99, 99].span, to: destPath)

            let options = File.System.Move.Options(overwrite: false)
            #expect(throws: File.System.Move.Error.self) {
                try File.System.Move.move(from: sourcePath, to: destPath, options: options)
            }
        }
    }

    @Test
    func `Options default values`() {
        let options = File.System.Move.Options()
        #expect(options.overwrite == false)
    }

    @Test
    func `Options custom values`() {
        let options = File.System.Move.Options(overwrite: true)
        #expect(options.overwrite == true)
    }

    // MARK: - Error Cases

    @Test
    func `Move non-existent source throws sourceNotFound`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "non-existent.bin"
            let destPath = dir.path / "dest.bin"

            #expect(throws: File.System.Move.Error.self) {
                try File.System.Move.move(from: sourcePath, to: destPath)
            }
        }
    }

    @Test
    func `Move to existing file without overwrite throws error with isDestinationExists`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99].span, to: destPath)

            do throws(File.System.Move.Error) {
                try File.System.Move.move(from: sourcePath, to: destPath)
                Issue.record("Expected error for existing destination")
            } catch {
                #expect(error.isDestinationExists)
            }
        }
    }

    // MARK: - Semantic Accessors

    @Test
    func `isSourceNotFound semantic accessor`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "non-existent.bin"
            let destPath = dir.path / "dest.bin"

            do throws(File.System.Move.Error) {
                try File.System.Move.move(from: sourcePath, to: destPath)
                Issue.record("Expected error for non-existent source")
            } catch {
                #expect(error.isSourceNotFound)
                #expect(!error.isDestinationExists)
            }
        }
    }

    @Test
    func `isDestinationExists semantic accessor`() throws {
        try File.Directory.temporary { dir in
            let sourcePath = dir.path / "source.bin"
            let destPath = dir.path / "dest.bin"

            try File.System.Write.Atomic.write([1, 2, 3].span, to: sourcePath)
            try File.System.Write.Atomic.write([99].span, to: destPath)

            do throws(File.System.Move.Error) {
                try File.System.Move.move(from: sourcePath, to: destPath)
                Issue.record("Expected error for existing destination")
            } catch {
                #expect(error.isDestinationExists)
                #expect(!error.isSourceNotFound)
            }
        }
    }

    @Test
    func `destinationExists error contains path in description`() throws {
        let path = File.Path("/tmp/existing")
        let error = File.System.Move.Error.destinationExists(path)
        #expect(error.description.contains("already exists"))
    }

    @Test
    func `rename error wraps Kernel.Rename.Error`() {
        let error = File.System.Move.Error.rename(.notFound)
        #expect(error.isSourceNotFound)
        #expect(error.description.contains("Rename failed"))
    }

    @Test
    func `isPermissionDenied semantic accessor`() {
        let error = File.System.Move.Error.rename(.permission)
        #expect(error.isPermissionDenied)
        #expect(!error.isSourceNotFound)
    }
}
