//
//  File.Directory.Walk.Undecodable.Context Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Directory.Walk.Undecodable.Context {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Directory.Walk.Undecodable.Context.Test.Unit {

    // MARK: - Initialization

    @Test("init stores all properties")
    func initStoresAllProperties() throws {
        let parent = try File.Path("/tmp/test")
        let name = File.Name(rawBytes: [0x80, 0x81])
        let type: File.Directory.Entry.Kind = .file
        let depth = 3

        let context = File.Directory.Walk.Undecodable.Context(
            parent: parent,
            name: name,
            type: type,
            depth: depth
        )

        #expect(context.parent == parent)
        #expect(context.name == name)
        #expect(context.type == type)
        #expect(context.depth == depth)
    }

    // MARK: - Parent Property

    @Test("parent property returns the parent path")
    func parentProperty() throws {
        let parent = try File.Path("/usr/local/bin")
        let context = File.Directory.Walk.Undecodable.Context(
            parent: parent,
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )

        #expect(context.parent == parent)
        #expect(context.parent.string == "/usr/local/bin")
    }

    // MARK: - Name Property

    @Test("name property returns the undecodable name")
    func nameProperty() throws {
        let name = File.Name(rawBytes: [0x80, 0x81, 0x82])
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: name,
            type: .file,
            depth: 0
        )

        #expect(context.name == name)
    }

    @Test("name.debugDescription is accessible for logging")
    func nameDebugDescription() throws {
        let name = File.Name(rawBytes: [0xAB, 0xCD])
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: name,
            type: .file,
            depth: 0
        )

        let debug = context.name.debugDescription
        #expect(debug.contains("invalidUTF8"))
        #expect(debug.contains("ABCD"))
    }

    @Test("name can be lossy decoded for display")
    func nameLossyDecoded() throws {
        let name = File.Name(rawBytes: [0x80])
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: name,
            type: .file,
            depth: 0
        )

        let lossy = String(lossy: context.name)
        #expect(lossy.contains("\u{FFFD}"))
    }

    // MARK: - Type Property

    @Test("type property returns file")
    func typePropertyFile() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )

        #expect(context.type == .file)
    }

    @Test("type property returns directory")
    func typePropertyDirectory() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .directory,
            depth: 0
        )

        #expect(context.type == .directory)
    }

    @Test("type property returns symbolicLink")
    func typePropertySymbolicLink() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .symbolicLink,
            depth: 0
        )

        #expect(context.type == .symbolicLink)
    }

    @Test("type property returns other")
    func typePropertyOther() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/dev"),
            name: File.Name(rawBytes: [0x80]),
            type: .other,
            depth: 0
        )

        #expect(context.type == .other)
    }

    // MARK: - Depth Property

    @Test("depth property returns zero for root directory")
    func depthZero() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )

        #expect(context.depth == 0)
    }

    @Test("depth property returns positive value for nested entries")
    func depthPositive() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp/a/b/c"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 3
        )

        #expect(context.depth == 3)
    }

    @Test("depth property can be large")
    func depthLarge() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/very/deep/path"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 100
        )

        #expect(context.depth == 100)
    }

    // MARK: - Sendable

    @Test("Context is Sendable")
    func sendable() async throws {
        let parent = try File.Path("/tmp")
        let name = File.Name(rawBytes: [0x80])
        let context = File.Directory.Walk.Undecodable.Context(
            parent: parent,
            name: name,
            type: .file,
            depth: 1
        )

        let result = await Task {
            (context.parent, context.name, context.type, context.depth)
        }.value

        #expect(result.0 == parent)
        #expect(result.1 == name)
        #expect(result.2 == .file)
        #expect(result.3 == 1)
    }
}

// MARK: - Edge Cases

extension File.Directory.Walk.Undecodable.Context.Test.EdgeCase {

    @Test("context with root path as parent")
    func rootPathParent() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )

        #expect(context.parent.string == "/")
    }

    @Test("context with unicode parent path")
    func unicodeParent() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/日本語/フォルダ"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 2
        )

        #expect(context.parent.string.contains("日本語"))
    }

    @Test("context with various invalid byte patterns")
    func variousInvalidBytes() throws {
        // Lone continuation byte
        let context1 = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 0
        )
        #expect(String(context1.name) == nil)

        // Invalid start byte
        let context2 = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0xFF]),
            type: .file,
            depth: 0
        )
        #expect(String(context2.name) == nil)

        // Overlong encoding
        let context3 = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0xC0, 0xAF]),
            type: .file,
            depth: 0
        )
        #expect(String(context3.name) == nil)
    }

    @Test("context used in callback pattern")
    func callbackPattern() throws {
        var capturedContext: File.Directory.Walk.Undecodable.Context?

        let handler:
            (File.Directory.Walk.Undecodable.Context) -> File.Directory.Walk.Undecodable.Policy = {
                context in
                capturedContext = context
                return .skip
            }

        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .directory,
            depth: 5
        )

        let policy = handler(context)

        #expect(capturedContext != nil)
        #expect(capturedContext?.parent == context.parent)
        #expect(capturedContext?.name == context.name)
        #expect(capturedContext?.type == context.type)
        #expect(capturedContext?.depth == context.depth)

        switch policy {
        case .skip:
            #expect(true)
        default:
            Issue.record("Expected skip")
        }
    }

    @Test("context properties can be destructured")
    func destructuring() throws {
        let context = File.Directory.Walk.Undecodable.Context(
            parent: try File.Path("/tmp"),
            name: File.Name(rawBytes: [0x80]),
            type: .file,
            depth: 2
        )

        let parent = context.parent
        let name = context.name
        let type = context.type
        let depth = context.depth

        #expect(parent.string == "/tmp")
        #expect(String(name) == nil)
        #expect(type == .file)
        #expect(depth == 2)
    }

    @Test("context can be stored in collection")
    func storedInCollection() throws {
        let contexts = [
            File.Directory.Walk.Undecodable.Context(
                parent: try File.Path("/tmp"),
                name: File.Name(rawBytes: [0x80]),
                type: .file,
                depth: 0
            ),
            File.Directory.Walk.Undecodable.Context(
                parent: try File.Path("/var"),
                name: File.Name(rawBytes: [0x81]),
                type: .directory,
                depth: 1
            ),
        ]

        #expect(contexts.count == 2)
        #expect(contexts[0].type == .file)
        #expect(contexts[1].type == .directory)
    }
}
