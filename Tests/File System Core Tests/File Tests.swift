//
//  File Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.Test.Unit {
    @Test
    func `init from path`() throws {
        let path = File.Path("/tmp/test.txt")
        let file = File(path)
        #expect(file.path == path)
    }

    @Test
    func `path property returns correct value`() throws {
        let path = File.Path("/usr/local/bin/test")
        let file = File(path)
        #expect(file.path == "/usr/local/bin/test")
    }

    @Test
    func `Hashable conformance - equal paths have equal hashes`() throws {
        let path = File.Path("/tmp/test.txt")
        let file1 = File(path)
        let file2 = File(path)
        #expect(file1.hashValue == file2.hashValue)
    }

    @Test
    func `Hashable conformance - different paths have different hashes`() throws {
        let path1 = File.Path("/tmp/test1.txt")
        let path2 = File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path2)
        #expect(file1.hashValue != file2.hashValue)
    }

    @Test
    func `Equatable conformance - equal files`() throws {
        let path = File.Path("/tmp/test.txt")
        let file1 = File(path)
        let file2 = File(path)
        #expect(file1 == file2)
    }

    @Test
    func `Equatable conformance - different files`() throws {
        let path1 = File.Path("/tmp/test1.txt")
        let path2 = File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path2)
        #expect(file1 != file2)
    }

    @Test
    func `Use in Set`() throws {
        let path1 = File.Path("/tmp/test1.txt")
        let path2 = File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path1)  // same as file1
        let file3 = File(path2)

        let set: Set<File> = [file1, file2, file3]
        #expect(set.count == 2)
    }

    @Test
    func `Use as Dictionary key`() throws {
        let path1 = File.Path("/tmp/test1.txt")
        let path2 = File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path2)

        var dict: [File: Int] = [:]
        dict[file1] = 1
        dict[file2] = 2

        #expect(dict[file1] == 1)
        #expect(dict[file2] == 2)
    }
}

// MARK: - Edge Cases

extension File.Test.`Edge Case` {
    @Test
    func `File with root path`() throws {
        let path = File.Path("/")
        let file = File(path)
        #expect(file.path == "/")
    }

    @Test
    func `File with deep nested path`() throws {
        let path = File.Path("/a/b/c/d/e/f/g/h/i/j/k.txt")
        let file = File(path)
        #expect(file.path == "/a/b/c/d/e/f/g/h/i/j/k.txt")
    }
}
