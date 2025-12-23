//
//  File.System.Write.Append Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Append {
    #TestSuites
}

extension File.System.Write.Append.Test.Unit {

    // MARK: - Basic Append

    @Test("Append to existing file")
    func appendToExistingFile() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([1, 2, 3], to: path)

            let appendData: [UInt8] = [4, 5, 6]
            try File.System.Write.Append.append(appendData.span, to: path)

            let data = try File.System.Read.Full.read(from: path)
            #expect(data == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test("Append creates file if not exists")
    func appendCreatesFileIfNotExists() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "new.bin")

            let appendData: [UInt8] = [10, 20, 30]
            try File.System.Write.Append.append(appendData.span, to: path)

            #expect(File.System.Stat.exists(at: path))

            let data = try File.System.Read.Full.read(from: path)
            #expect(data == [10, 20, 30])
        }
    }

    @Test("Append empty data")
    func appendEmptyData() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([1, 2, 3], to: path)

            let emptyData: [UInt8] = []
            try File.System.Write.Append.append(emptyData.span, to: path)

            let data = try File.System.Read.Full.read(from: path)
            #expect(data == [1, 2, 3])
        }
    }

    @Test("Multiple appends")
    func multipleAppends() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([], to: path)

            let data1: [UInt8] = [1, 2]
            let data2: [UInt8] = [3, 4]
            let data3: [UInt8] = [5, 6]
            try File.System.Write.Append.append(data1.span, to: path)
            try File.System.Write.Append.append(data2.span, to: path)
            try File.System.Write.Append.append(data3.span, to: path)

            let data = try File.System.Read.Full.read(from: path)
            #expect(data == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test("Append to empty file")
    func appendToEmptyFile() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([], to: path)

            let appendData: [UInt8] = [1, 2, 3]
            try File.System.Write.Append.append(appendData.span, to: path)

            let data = try File.System.Read.Full.read(from: path)
            #expect(data == [1, 2, 3])
        }
    }

    @Test("Append large data")
    func appendLargeData() throws {
        try File.Directory.temporary { dir in
            let path = File.Path(dir.path, appending: "test.bin")
            try File.System.Write.Atomic.write([], to: path)

            let largeData = [UInt8](repeating: 42, count: 100_000)
            try File.System.Write.Append.append(largeData.span, to: path)

            let data = try File.System.Read.Full.read(from: path)
            #expect(data.count == 100_000)
        }
    }

    // MARK: - Error Cases

    @Test("Append to directory throws isDirectory")
    func appendToDirectoryThrows() throws {
        try File.Directory.temporary { dir in
            let path = dir.path

            #expect(throws: File.System.Write.Append.Error.isDirectory(path)) {
                let bytes: [UInt8] = [1, 2, 3]
                try File.System.Write.Append.append(bytes.span, to: path)
            }
        }
    }

    // MARK: - Error Descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() {
        let path: File.Path = "/tmp/missing/nested/file.txt"
        let error = File.System.Write.Append.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() {
        let path: File.Path = "/root/secret.txt"
        let error = File.System.Write.Append.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("isDirectory error description")
    func isDirectoryErrorDescription() {
        let path: File.Path = "/tmp"
        let error = File.System.Write.Append.Error.isDirectory(path)
        #expect(error.description.contains("Is a directory"))
    }

    @Test("writeFailed error description")
    func writeFailedErrorDescription() {
        let error = File.System.Write.Append.Error.writeFailed(
            errno: 28,
            message: "No space left"
        )
        #expect(error.description.contains("Write failed"))
        #expect(error.description.contains("No space left"))
    }

    // MARK: - Error Equatable

    @Test("Errors are equatable")
    func errorsAreEquatable() {
        let path1: File.Path = "/tmp/a"
        let path2: File.Path = "/tmp/a"

        #expect(
            File.System.Write.Append.Error.pathNotFound(path1)
                == File.System.Write.Append.Error.pathNotFound(path2)
        )
        #expect(
            File.System.Write.Append.Error.isDirectory(path1)
                == File.System.Write.Append.Error.isDirectory(path2)
        )
    }
}
