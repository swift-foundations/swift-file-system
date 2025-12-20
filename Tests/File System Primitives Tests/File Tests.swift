//
//  File Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Test.Unit {
    @Test("init from path")
    func initFromPath() throws {
        let path = try File.Path("/tmp/test.txt")
        let file = File(path)
        #expect(file.path == path)
    }

    @Test("path property returns correct value")
    func pathProperty() throws {
        let path = try File.Path("/usr/local/bin/test")
        let file = File(path)
        #expect(file.path.string == "/usr/local/bin/test")
    }

    @Test("Hashable conformance - equal paths have equal hashes")
    func hashableConformanceEqual() throws {
        let path = try File.Path("/tmp/test.txt")
        let file1 = File(path)
        let file2 = File(path)
        #expect(file1.hashValue == file2.hashValue)
    }

    @Test("Hashable conformance - different paths have different hashes")
    func hashableConformanceDifferent() throws {
        let path1 = try File.Path("/tmp/test1.txt")
        let path2 = try File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path2)
        #expect(file1.hashValue != file2.hashValue)
    }

    @Test("Equatable conformance - equal files")
    func equatableConformanceEqual() throws {
        let path = try File.Path("/tmp/test.txt")
        let file1 = File(path)
        let file2 = File(path)
        #expect(file1 == file2)
    }

    @Test("Equatable conformance - different files")
    func equatableConformanceDifferent() throws {
        let path1 = try File.Path("/tmp/test1.txt")
        let path2 = try File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path2)
        #expect(file1 != file2)
    }

    @Test("Use in Set")
    func useInSet() throws {
        let path1 = try File.Path("/tmp/test1.txt")
        let path2 = try File.Path("/tmp/test2.txt")
        let file1 = File(path1)
        let file2 = File(path1) // same as file1
        let file3 = File(path2)

        let set: Set<File> = [file1, file2, file3]
        #expect(set.count == 2)
    }

    @Test("Use as Dictionary key")
    func useAsDictionaryKey() throws {
        let path1 = try File.Path("/tmp/test1.txt")
        let path2 = try File.Path("/tmp/test2.txt")
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

extension File.Test.EdgeCase {
    @Test("File with root path")
    func fileWithRootPath() throws {
        let path = try File.Path("/")
        let file = File(path)
        #expect(file.path.string == "/")
    }

    @Test("File with deep nested path")
    func fileWithDeepNestedPath() throws {
        let path = try File.Path("/a/b/c/d/e/f/g/h/i/j/k.txt")
        let file = File(path)
        #expect(file.path.string == "/a/b/c/d/e/f/g/h/i/j/k.txt")
    }
}
