//
//  File.Directory Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Test.Unit {
    @Test("init from path")
    func initFromPath() throws {
        let path = File.Path("/tmp/mydir")
        let dir = File.Directory(path)
        #expect(dir.path == path)
    }

    @Test("init from string")
    func initFromString() throws {
        let dir = try File.Directory("/tmp/mydir")
        #expect(dir.path.string == "/tmp/mydir")
    }

    @Test("path property returns correct value")
    func pathProperty() throws {
        let path = File.Path("/usr/local/lib")
        let dir = File.Directory(path)
        #expect(dir.path.string == "/usr/local/lib")
    }

    @Test("Hashable conformance - equal paths have equal hashes")
    func hashableConformanceEqual() throws {
        let path = File.Path("/tmp/mydir")
        let dir1 = File.Directory(path)
        let dir2 = File.Directory(path)
        #expect(dir1.hashValue == dir2.hashValue)
    }

    @Test("Hashable conformance - different paths have different hashes")
    func hashableConformanceDifferent() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path2)
        #expect(dir1.hashValue != dir2.hashValue)
    }

    @Test("Equatable conformance - equal directories")
    func equatableConformanceEqual() throws {
        let path = File.Path("/tmp/mydir")
        let dir1 = File.Directory(path)
        let dir2 = File.Directory(path)
        #expect(dir1 == dir2)
    }

    @Test("Equatable conformance - different directories")
    func equatableConformanceDifferent() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path2)
        #expect(dir1 != dir2)
    }

    @Test("Use in Set")
    func useInSet() throws {
        let path1 = File.Path("/tmp/dir1")
        let path2 = File.Path("/tmp/dir2")
        let dir1 = File.Directory(path1)
        let dir2 = File.Directory(path1)  // same as dir1
        let dir3 = File.Directory(path2)

        let set: Set<File.Directory> = [dir1, dir2, dir3]
        #expect(set.count == 2)
    }

    @Test("Use as Dictionary key")
    func useAsDictionaryKey() throws {
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

extension File.Directory.Test.EdgeCase {
    @Test("Directory with root path")
    func directoryWithRootPath() throws {
        let path = File.Path("/")
        let dir = File.Directory(path)
        #expect(dir.path.string == "/")
    }

    @Test("init from invalid string throws")
    func initFromInvalidString() {
        #expect(throws: File.Path.Error.self) {
            _ = try File.Directory("")
        }
    }

    @Test("init from string with control characters throws")
    func initFromStringWithControlCharacters() {
        #expect(throws: File.Path.Error.self) {
            _ = try File.Directory("/tmp/dir\0name")
        }
    }
}
