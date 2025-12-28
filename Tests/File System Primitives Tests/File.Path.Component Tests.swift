//
//  File.Path.Component Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import SystemPackage
import Testing

@testable import File_System_Primitives

extension File.Path.Component {
    #TestSuites
}

extension File.Path.Component.Test.Unit {
    // MARK: - Initialization

    @Test("Valid component initialization")
    func validComponent() throws {
        let component: File.Path.Component = try .init("file.txt")
        #expect(component.string == "file.txt")
    }

    @Test("Component with special characters")
    func componentWithSpecialCharacters() throws {
        let component: File.Path.Component = try .init("file-name_v2.0.txt")
        #expect(component.string == "file-name_v2.0.txt")
    }

    @Test("Component with spaces")
    func componentWithSpaces() throws {
        let component: File.Path.Component = try .init("my file.txt")
        #expect(component.string == "my file.txt")
    }

    @Test("Empty component throws error")
    func emptyComponent() {
        let emptyString = ""
        #expect(throws: File.Path.Component.Error.empty) {
            try File.Path.Component(emptyString)
        }
    }

    @Test("Component with path separator throws error")
    func componentWithPathSeparator() {
        let componentWithSep = "foo/bar"
        #expect(throws: File.Path.Component.Error.containsPathSeparator) {
            try File.Path.Component(componentWithSep)
        }
    }

    // MARK: - Properties

    @Test("String property")
    func stringProperty() throws {
        let component: File.Path.Component = try .init("file.txt")
        #expect(component.string == "file.txt")
    }

    @Test("Extension of component with extension")
    func extensionOfComponent() throws {
        let component: File.Path.Component = try .init("file.txt")
        #expect(component.extension == "txt")
    }

    @Test("Extension of component without extension")
    func extensionOfComponentWithoutExtension() throws {
        let component: File.Path.Component = try .init("Makefile")
        #expect(component.extension == nil)
    }

    @Test("Extension of component with multiple dots")
    func extensionOfComponentWithMultipleDots() throws {
        let component: File.Path.Component = try .init("file.tar.gz")
        #expect(component.extension == "gz")
    }

    @Test("Stem of component with extension")
    func stemOfComponent() throws {
        let component: File.Path.Component = try .init("file.txt")
        #expect(component.stem == "file")
    }

    @Test("Stem of component without extension")
    func stemOfComponentWithoutExtension() throws {
        let component: File.Path.Component = try .init("Makefile")
        #expect(component.stem == "Makefile")
    }

    @Test("Stem of component with multiple dots")
    func stemOfComponentWithMultipleDots() throws {
        let component: File.Path.Component = try .init("file.tar.gz")
        #expect(component.stem == "file.tar")
    }

    @Test("FilePathComponent conversion")
    func filePathComponentConversion() throws {
        let component: File.Path.Component = try .init("file.txt")
        #expect(component.filePathComponent == FilePath.Component("file.txt"))
    }

    // MARK: - Protocols

    @Test("Hashable conformance")
    func hashableConformance() throws {
        let comp1: File.Path.Component = try .init("file.txt")
        let comp2: File.Path.Component = try .init("file.txt")
        let comp3: File.Path.Component = try .init("other.txt")

        #expect(comp1.hashValue == comp2.hashValue)
        #expect(comp1.hashValue != comp3.hashValue)
    }

    @Test("Equatable conformance")
    func equatableConformance() throws {
        let comp1: File.Path.Component = try .init("file.txt")
        let comp2: File.Path.Component = try .init("file.txt")
        let comp3: File.Path.Component = try .init("other.txt")

        #expect(comp1 == comp2)
        #expect(comp1 != comp3)
    }

    @Test("ExpressibleByStringLiteral")
    func expressibleByStringLiteral() {
        let component: File.Path.Component = "file.txt"
        #expect(component.string == "file.txt")
    }

    @Test("Use in Set")
    func useInSet() throws {
        let comp1: File.Path.Component = try .init("file.txt")
        let comp2: File.Path.Component = try .init("file.txt")
        let comp3: File.Path.Component = try .init("other.txt")

        let set: Set<File.Path.Component> = [comp1, comp2, comp3]
        #expect(set.count == 2)
    }

    @Test("Use as Dictionary key")
    func useAsDictionaryKey() throws {
        let comp1: File.Path.Component = try .init("file.txt")
        let comp2: File.Path.Component = try .init("other.txt")

        var dict: [File.Path.Component: Int] = [:]
        dict[comp1] = 1
        dict[comp2] = 2

        #expect(dict[comp1] == 1)
        #expect(dict[comp2] == 2)
    }

    // MARK: - Integration with File.Path

    @Test("Component can be appended to path")
    func componentAppendedToPath() throws {
        let path = File.Path("/usr/local")
        let component: File.Path.Component = try .init("bin")
        let newPath = File.Path(path, appending: component)
        #expect(newPath == "/usr/local/bin")
    }

    @Test("Path lastComponent returns component")
    func pathLastComponentReturnsComponent() throws {
        let path = File.Path("/usr/local/bin")
        let lastComp = path.lastComponent
        #expect(lastComp?.string == "bin")
    }
}
