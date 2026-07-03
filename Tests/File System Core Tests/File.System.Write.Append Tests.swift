//
//  File.System.Write.Append Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Append {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Append.Test.Unit {

    // MARK: - Basic Append

    @Test
    func `Append to existing file`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            try File.System.Write.Atomic.write([1, 2, 3], to: path)

            let appendData: [Byte] = [4, 5, 6]
            try File.System.Write.Append.append(appendData.span, to: path)

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test
    func `Append creates file if not exists`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "new.bin"

            let appendData: [Byte] = [10, 20, 30]
            try File.System.Write.Append.append(appendData.span, to: path)

            #expect(File.System.Stat.exists(at: path))

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [10, 20, 30])
        }
    }

    @Test
    func `Append empty data`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            try File.System.Write.Atomic.write([1, 2, 3], to: path)

            let emptyData: [Byte] = []
            try File.System.Write.Append.append(emptyData.span, to: path)

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [1, 2, 3])
        }
    }

    @Test
    func `Multiple appends`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty, to: path)

            let data1: [Byte] = [1, 2]
            let data2: [Byte] = [3, 4]
            let data3: [Byte] = [5, 6]
            try File.System.Write.Append.append(data1.span, to: path)
            try File.System.Write.Append.append(data2.span, to: path)
            try File.System.Write.Append.append(data3.span, to: path)

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test
    func `Append to empty file`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty, to: path)

            let appendData: [Byte] = [1, 2, 3]
            try File.System.Write.Append.append(appendData.span, to: path)

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data == [1, 2, 3])
        }
    }

    @Test
    func `Append large data`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path / "test.bin"
            let empty: [Byte] = []
            try File.System.Write.Atomic.write(empty, to: path)

            let largeData = [Byte](repeating: 42, count: 100_000)
            try File.System.Write.Append.append(largeData.span, to: path)

            let data = try File.System.Read.Full.read(from: path) { $0.withUnsafeBytes { unsafe $0.map(Byte.init) } }
            #expect(data.count == 100_000)
        }
    }

    // MARK: - Error Cases

    @Test
    func `Append to directory throws error`() throws {
        try File.Directory.temporary { dir in
            let path = dir.path

            // Windows returns permissionDenied for directory write attempts,
            // while POSIX systems return isDirectory
            #expect(throws: File.System.Write.Append.Error.self) {
                let bytes: [Byte] = [1, 2, 3]
                try File.System.Write.Append.append(bytes.span, to: path)
            }
        }
    }

    // MARK: - Semantic Accessors

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isNotFound semantic accessor`() {
            let error = File.System.Write.Append.Error.open(.path(.notFound))
            #expect(error.isNotFound)
            #expect(!error.isPermissionDenied)
        }
    #endif

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isPermissionDenied semantic accessor`() {
            let error = File.System.Write.Append.Error.open(.platform(Error_Primitives.Error(code: .POSIX.EACCES)))
            #expect(error.isPermissionDenied)
            #expect(!error.isNotFound)
        }
    #endif

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isDirectory semantic accessor`() {
            let error = File.System.Write.Append.Error.open(.path(.isDirectory))
            #expect(error.isDirectory)
            #expect(!error.isNotFound)
        }
    #endif

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isReadOnly semantic accessor`() {
            let error = File.System.Write.Append.Error.open(.platform(Error_Primitives.Error(code: .POSIX.EROFS)))
            #expect(error.isReadOnly)
            #expect(!error.isPermissionDenied)
        }
    #endif

    // POSIX error-code construction; the accessor maps Win32 codes on Windows.
    #if !os(Windows)
        @Test
        func `isNoSpace semantic accessor`() {
            let error = File.System.Write.Append.Error.open(.platform(Error_Primitives.Error(code: .POSIX.ENOSPC)))
            #expect(error.isNoSpace)
            #expect(!error.isNotFound)
        }
    #endif

    @Test
    func `Error description contains failure message`() {
        let error = File.System.Write.Append.Error.open(.path(.notFound))
        #expect(error.description.contains("Open failed"))
    }
}
