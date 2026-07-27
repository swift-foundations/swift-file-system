// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-file-system open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-file-system project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import File_System_Test_Support
import Kernel
import Testing

@testable import File_System_Core

extension File.System.Canonical {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension File.System.Canonical.Test.Unit {
    @Test
    func `Resolve existing directory`() throws {
        try File.Directory.temporary { directory in
            let resolved = try File.System.Canonical.resolve(directory.path)
            #expect(try File.System.same(resolved, directory.path))
        }
    }

    #if !os(Windows)
        @Test
        func `Resolve symbolic link target`() throws {
            try File.Directory.temporary { directory in
                let target = directory.path / "target"
                try File.System.Create.Directory.create(at: target)

                let link = directory.path / "link"
                try File.System.Link.Symbolic.create(at: link, pointingTo: target)

                let resolved = try File.System.Canonical.resolve(link)
                #expect(try File.System.same(resolved, target))
            }
        }

        #if os(Linux) || os(Android)
            @Test
            func `Resolve preserves native path code units`() throws {
                try File.Directory.temporary { directory in
                    let bytes: [File.Path.Char] = [0xFF]
                    let component = try File.Path(copying: bytes.span)
                    let target = directory.path / component
                    try File.System.Create.Directory.create(at: target)

                    let resolved = try File.System.Canonical.resolve(target)
                    #expect(try File.System.same(resolved, target))
                    #expect(resolved.components.last == component.components.last)
                }
            }
        #endif

        @Test
        func `Resolve reports an unrepresentable physical target`() throws {
            try File.Directory.temporary { directory in
                var rawTarget: [File.Path.Char] = directory.path.withKernelPath { path in
                    var bytes: [File.Path.Char] = []
                    bytes.reserveCapacity(path.count + 3)
                    for index in 0..<path.count {
                        bytes.append(path.span[index])
                    }
                    return bytes
                }
                rawTarget.append(0x2F)
                rawTarget.append(0x01)
                rawTarget.append(0)

                try unsafe rawTarget.withUnsafeBufferPointer { pointer throws(Kernel.Directory.Create.Error) in
                    let path = unsafe Path.Borrowed(
                        pointer.baseAddress!,
                        count: pointer.count - 1
                    )
                    try Kernel.Directory.Create.create(path)
                }
                defer {
                    try? unsafe rawTarget.withUnsafeBufferPointer { pointer throws(Kernel.Directory.Remove.Error) in
                        let path = unsafe Path.Borrowed(
                            pointer.baseAddress!,
                            count: pointer.count - 1
                        )
                        try Kernel.Directory.Remove.remove(path)
                    }
                }

                let link = directory.path / "link"
                try unsafe rawTarget.withUnsafeBufferPointer { targetPointer throws(Kernel.Link.Symbolic.Error) in
                    let target = unsafe Path.Borrowed(
                        targetPointer.baseAddress!,
                        count: targetPointer.count - 1
                    )
                    try link.withKernelPath { linkPath throws(Kernel.Link.Symbolic.Error) in
                        try Kernel.Link.Symbolic.create(target: target, at: linkPath)
                    }
                }
                defer { try? File.System.Delete.delete(at: link) }

                do throws(File.System.Canonical.Error) {
                    _ = try File.System.Canonical.resolve(link)
                    Issue.record("Expected the physical target to fail File.Path validation")
                } catch {
                    #expect(error == .representation(.containsControlCharacters))
                }
            }
        }
    #endif

    @Test
    func `Resolve nonexistent path reports not found`() throws {
        try File.Directory.temporary { directory in
            let nonexistent = directory.path / "nonexistent"

            do throws(File.System.Canonical.Error) {
                _ = try File.System.Canonical.resolve(nonexistent)
                Issue.record("Expected nonexistent path to fail resolution")
            } catch {
                #expect(error == .resolution(.path(.notFound)))
                #expect(error.isNotFound)
            }
        }
    }
}

#if !os(Windows)
    extension File.System.Canonical.Test.`Edge Case` {
        @Test
        func `Resolve symbolic link loop reports loop`() throws {
            try File.Directory.temporary { directory in
                let first = directory.path / "first"
                let second = directory.path / "second"
                try File.System.Link.Symbolic.create(at: first, pointingTo: second)
                try File.System.Link.Symbolic.create(at: second, pointingTo: first)

                do throws(File.System.Canonical.Error) {
                    _ = try File.System.Canonical.resolve(first)
                    Issue.record("Expected symbolic-link loop to fail resolution")
                } catch {
                    #expect(error == .resolution(.path(.loop)))
                    #expect(error.isLoop)
                }
            }
        }
    }
#endif
