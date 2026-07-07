//
//  File.Directory Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.Directory {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.Directory.Test.Unit {
    @Test
    func `init from path`() throws {
        let path = File.Path("/tmp/mydir")
        let dir = File.Directory(path)
        #expect(dir.path == path)
    }

    @Test
    func `init from path literal`() throws {
        let dir = File.Directory("/tmp/mydir")
        #expect(dir.path == "/tmp/mydir")
    }

    @Test
    func `path property returns correct value`() throws {
        let path: File.Path = "/usr/local/lib"
        let dir = File.Directory(path)
        #expect(dir.path == "/usr/local/lib")
    }

    @Test
    func `Hashable conformance - equal paths have equal hashes`() throws {
        let path = File.Path("/tmp/mydir")
        let dir1 = File.Directory(path)
        let dir2 = File.Directory(path)
        #expect(dir1.hashValue == dir2.hashValue)
    }

    @Test
    func `Hashable conformance - different paths have different hashes`() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path2)
        #expect(dir1.hashValue != dir2.hashValue)
    }

    @Test
    func `Equatable conformance - equal directories`() throws {
        let path = File.Path("/tmp/mydir")
        let dir1 = File.Directory(path)
        let dir2 = File.Directory(path)
        #expect(dir1 == dir2)
    }

    @Test
    func `Equatable conformance - different directories`() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path2)
        #expect(dir1 != dir2)
    }

    @Test
    func `Use in Set`() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path1)  // same as dir1
        let dir3 = File.Directory(path2)

        let set: Set<File.Directory> = [dir1, dir2, dir3]
        #expect(set.count == 2)
    }

    @Test
    func `Use as Dictionary key`() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path2)

        var dict: [File.Directory: Int] = [:]
        dict[dir1] = 1
        dict[dir2] = 2

        #expect(dict[dir1] == 1)
        #expect(dict[dir2] == 2)
    }
}

// MARK: - Edge Cases

extension File.Directory.Test.`Edge Case` {
    @Test
    func `Directory with root path`() throws {
        let path: File.Path = "/"
        let dir = File.Directory(path)
        #expect(dir.path == "/")
    }

    @Test
    func `Validating empty string throws`() {
        #expect(throws: File.Path.Error.self) {
            _ = try File.Directory(validating: "")
        }
    }

    @Test
    func `Validating string with control characters throws`() {
        #expect(throws: File.Path.Error.self) {
            _ = try File.Directory(validating: "/tmp/dir\0name")
        }
    }
}
