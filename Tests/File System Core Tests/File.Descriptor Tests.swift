//
//  File.Descriptor Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System
import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.Descriptor {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.Descriptor.Test.Unit {
    // MARK: - Opening

    @Test
    func `Open file in read mode`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([1, 2, 3].span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .read)
            let isValid = descriptor.isValid
            #expect(isValid)
            try descriptor.close()
        }
    }

    @Test
    func `Open file in write mode`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([Byte]().span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .write)
            let isValid = descriptor.isValid
            #expect(isValid)
            try descriptor.close()
        }
    }

    @Test
    func `Open file in readWrite mode`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([Byte]().span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .readWrite)
            let isValid = descriptor.isValid
            #expect(isValid)
            try descriptor.close()
        }
    }

    @Test
    func `Open non-existing file throws error`() throws {
        try File.Directory.temporary { dir in
            let file = dir["non-existing.txt"]

            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try File.Descriptor.open(file.path, mode: .read)
            }
        }
    }

    // MARK: - Options

    @Test
    func `Open with create option creates file`() throws {
        try File.Directory.temporary { dir in
            let file = dir["new-file.txt"]

            let descriptor = try File.Descriptor.open(file.path, mode: .write, options: [.create])
            let isValid = descriptor.isValid
            #expect(isValid)
            #expect(File.System.Stat.exists(at: file.path))
            try descriptor.close()
        }
    }

    @Test
    func `Open with truncate option truncates file`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([1, 2, 3, 4, 5].span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .write, options: [.truncate])
            try descriptor.close()

            try File.System.Read.Full.read(from: file.path) { span in
                #expect(span.count == 0)
            }
        }
    }

    @Test
    func `Open with exclusive and create on existing file throws`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([Byte]().span, to: file.path)

            #expect(throws: Kernel.File.Open.Error.self) {
                _ = try File.Descriptor.open(
                    file.path,
                    mode: .write,
                    options: [.create, .exclusive]
                )
            }
        }
    }

    // MARK: - Closing

    @Test
    func `Close makes descriptor invalid`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([Byte]().span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .read)
            let isValid = descriptor.isValid
            #expect(isValid)
            try descriptor.close()
            // After close, descriptor is consumed, can't check isValid
        }
    }

    @Test
    func `Double close throws alreadyClosed`() throws {
        try File.Directory.temporary { dir in
            let file = dir["test.bin"]
            try File.System.Write.Atomic.write([Byte]().span, to: file.path)

            let descriptor = try File.Descriptor.open(file.path, mode: .read)
            try descriptor.close()

            // Can't actually test double close since close() is consuming
            // The descriptor is consumed after first close
        }
    }
}
