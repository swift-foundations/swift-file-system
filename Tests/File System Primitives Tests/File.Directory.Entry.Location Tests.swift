//
//  File.Directory.Entry.Location Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Entry.Location {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Entry.Location.Test.Unit {

    // MARK: - Absolute Case

    @Test("absolute case stores parent and path")
    func absoluteStoresParentAndPath() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        switch location {
        case .absolute(let storedParent, let storedPath):
            #expect(storedParent == parent)
            #expect(storedPath == path)
        case .relative:
            Issue.record("Expected absolute, got relative")
        }
    }

    @Test("absolute case parent accessor returns parent")
    func absoluteParentAccessor() throws {
        let parent = try File.Path("/usr/local")
        let path = try File.Path("/usr/local/bin")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.parent == parent)
    }

    @Test("absolute case path accessor returns path")
    func absolutePathAccessor() throws {
        let parent = try File.Path("/var")
        let path = try File.Path("/var/log")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.path == path)
    }

    // MARK: - Relative Case

    @Test("relative case stores only parent")
    func relativeStoresParent() throws {
        let parent = try File.Path("/tmp")

        let location = File.Directory.Entry.Location.relative(parent: parent)

        switch location {
        case .absolute:
            Issue.record("Expected relative, got absolute")
        case .relative(let storedParent):
            #expect(storedParent == parent)
        }
    }

    @Test("relative case parent accessor returns parent")
    func relativeParentAccessor() throws {
        let parent = try File.Path("/home/user")

        let location = File.Directory.Entry.Location.relative(parent: parent)

        #expect(location.parent == parent)
    }

    @Test("relative case path accessor returns nil")
    func relativePathAccessorReturnsNil() throws {
        let parent = try File.Path("/tmp")

        let location = File.Directory.Entry.Location.relative(parent: parent)

        #expect(location.path == nil)
    }

    // MARK: - Equatable

    @Test("absolute locations are equal when parent and path match")
    func absoluteEquatable() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")

        let loc1 = File.Directory.Entry.Location.absolute(parent: parent, path: path)
        let loc2 = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(loc1 == loc2)
    }

    @Test("absolute locations differ when path differs")
    func absoluteNotEqualDifferentPath() throws {
        let parent = try File.Path("/tmp")
        let path1 = try File.Path("/tmp/file1.txt")
        let path2 = try File.Path("/tmp/file2.txt")

        let loc1 = File.Directory.Entry.Location.absolute(parent: parent, path: path1)
        let loc2 = File.Directory.Entry.Location.absolute(parent: parent, path: path2)

        #expect(loc1 != loc2)
    }

    @Test("absolute locations differ when parent differs")
    func absoluteNotEqualDifferentParent() throws {
        let parent1 = try File.Path("/tmp")
        let parent2 = try File.Path("/var")
        let path = try File.Path("/tmp/file.txt")

        let loc1 = File.Directory.Entry.Location.absolute(parent: parent1, path: path)
        let loc2 = File.Directory.Entry.Location.absolute(parent: parent2, path: path)

        #expect(loc1 != loc2)
    }

    @Test("relative locations are equal when parent matches")
    func relativeEquatable() throws {
        let parent = try File.Path("/tmp")

        let loc1 = File.Directory.Entry.Location.relative(parent: parent)
        let loc2 = File.Directory.Entry.Location.relative(parent: parent)

        #expect(loc1 == loc2)
    }

    @Test("relative locations differ when parent differs")
    func relativeNotEqualDifferentParent() throws {
        let parent1 = try File.Path("/tmp")
        let parent2 = try File.Path("/var")

        let loc1 = File.Directory.Entry.Location.relative(parent: parent1)
        let loc2 = File.Directory.Entry.Location.relative(parent: parent2)

        #expect(loc1 != loc2)
    }

    @Test("absolute and relative locations are never equal")
    func absoluteNotEqualRelative() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")

        let absolute = File.Directory.Entry.Location.absolute(parent: parent, path: path)
        let relative = File.Directory.Entry.Location.relative(parent: parent)

        #expect(absolute != relative)
    }

    // MARK: - Sendable

    @Test("Location is Sendable")
    func sendable() async throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")
        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        let result = await Task {
            location.path
        }.value

        #expect(result == path)
    }
}

// MARK: - Edge Cases

extension File.Directory.Entry.Location.Test.EdgeCase {

    @Test("root path as parent")
    func rootPathAsParent() throws {
        let root = try File.Path("/")
        let path = try File.Path("/file.txt")

        let location = File.Directory.Entry.Location.absolute(parent: root, path: path)

        #expect(location.parent.string == "/")
        #expect(location.path?.string == "/file.txt")
    }

    @Test("deep nested path")
    func deepNestedPath() throws {
        let parent = try File.Path("/a/b/c/d/e/f/g/h/i/j")
        let path = try File.Path("/a/b/c/d/e/f/g/h/i/j/file.txt")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.parent == parent)
        #expect(location.path == path)
    }

    @Test("path with spaces")
    func pathWithSpaces() throws {
        let parent = try File.Path("/Users/test user/Documents")
        let path = try File.Path("/Users/test user/Documents/my file.txt")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.path?.string.contains(" ") == true)
    }

    @Test("path with unicode characters")
    func pathWithUnicode() throws {
        let parent = try File.Path("/Users/日本語")
        let path = try File.Path("/Users/日本語/ファイル.txt")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.parent.string.contains("日本語"))
        #expect(location.path?.string.contains("ファイル") == true)
    }

    @Test("parent and path can be different paths (edge case)")
    func parentPathMismatch() throws {
        // This is technically valid - the Entry stores what it's given
        // Semantic correctness is the caller's responsibility
        let parent = try File.Path("/foo")
        let path = try File.Path("/bar/baz")

        let location = File.Directory.Entry.Location.absolute(parent: parent, path: path)

        #expect(location.parent == parent)
        #expect(location.path == path)
    }

    @Test("Location in switch statement")
    func locationSwitch() throws {
        let parent = try File.Path("/tmp")
        let path = try File.Path("/tmp/file.txt")

        let locations: [File.Directory.Entry.Location] = [
            .absolute(parent: parent, path: path),
            .relative(parent: parent),
        ]

        var absoluteCount = 0
        var relativeCount = 0

        for location in locations {
            switch location {
            case .absolute:
                absoluteCount += 1
            case .relative:
                relativeCount += 1
            }
        }

        #expect(absoluteCount == 1)
        #expect(relativeCount == 1)
    }

    @Test("Location used in collection")
    func locationInCollection() throws {
        let parent = try File.Path("/tmp")
        let path1 = try File.Path("/tmp/file1.txt")
        let path2 = try File.Path("/tmp/file2.txt")

        let locations: [File.Directory.Entry.Location] = [
            .absolute(parent: parent, path: path1),
            .absolute(parent: parent, path: path2),
            .relative(parent: parent),
        ]

        #expect(locations.count == 3)

        let pathCount = locations.compactMap(\.path).count
        #expect(pathCount == 2)  // Only absolute locations have paths
    }
}
