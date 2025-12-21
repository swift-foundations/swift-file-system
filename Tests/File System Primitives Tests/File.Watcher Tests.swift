//
//  File.Watcher Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Watcher {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Watcher.Test.Unit {
    // File.Watcher is currently a namespace with nested types
    // Tests focus on the nested types: Event, Event.Kind, Options
}

// MARK: - Event Tests

extension File.Watcher.Test.Unit {
    @Test("Event init")
    func eventInit() throws {
        let path = try File.Path("/tmp/watched.txt")
        let event = File.Watcher.Event(path: path, type: .created)

        #expect(event.path == path)
        #expect(event.type == .created)
    }

    @Test("Event with different types")
    func eventWithDifferentTypes() throws {
        let path = try File.Path("/tmp/watched.txt")

        let created = File.Watcher.Event(path: path, type: .created)
        #expect(created.type == .created)

        let modified = File.Watcher.Event(path: path, type: .modified)
        #expect(modified.type == .modified)

        let deleted = File.Watcher.Event(path: path, type: .deleted)
        #expect(deleted.type == .deleted)

        let renamed = File.Watcher.Event(path: path, type: .renamed)
        #expect(renamed.type == .renamed)

        let attributesChanged = File.Watcher.Event(path: path, type: .attributesChanged)
        #expect(attributesChanged.type == .attributesChanged)
    }
}

// MARK: - Event.Kind Tests

extension File.Watcher.Test.Unit {
    @Test("EventType all cases are distinct")
    func eventTypeAllCasesDistinct() {
        let allCases: [File.Watcher.Event.Kind] = [
            .created, .modified, .deleted, .renamed, .attributesChanged,
        ]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test("EventType rawValue for .created")
    func eventTypeRawValueCreated() {
        #expect(File.Watcher.Event.Kind.created.rawValue == 0)
    }

    @Test("EventType rawValue for .modified")
    func eventTypeRawValueModified() {
        #expect(File.Watcher.Event.Kind.modified.rawValue == 1)
    }

    @Test("EventType rawValue for .deleted")
    func eventTypeRawValueDeleted() {
        #expect(File.Watcher.Event.Kind.deleted.rawValue == 2)
    }

    @Test("EventType rawValue for .renamed")
    func eventTypeRawValueRenamed() {
        #expect(File.Watcher.Event.Kind.renamed.rawValue == 3)
    }

    @Test("EventType rawValue for .attributesChanged")
    func eventTypeRawValueAttributesChanged() {
        #expect(File.Watcher.Event.Kind.attributesChanged.rawValue == 4)
    }

    @Test("EventType rawValue round-trip")
    func eventTypeRawValueRoundTrip() {
        let allCases: [File.Watcher.Event.Kind] = [
            .created, .modified, .deleted, .renamed, .attributesChanged,
        ]
        for eventType in allCases {
            let restored = File.Watcher.Event.Kind(rawValue: eventType.rawValue)
            #expect(restored == eventType)
        }
    }

    @Test("EventType Binary.Serializable")
    func eventTypeBinarySerialize() {
        var buffer: [UInt8] = []
        File.Watcher.Event.Kind.serialize(.created, into: &buffer)
        #expect(buffer == [0])

        buffer = []
        File.Watcher.Event.Kind.serialize(.modified, into: &buffer)
        #expect(buffer == [1])

        buffer = []
        File.Watcher.Event.Kind.serialize(.deleted, into: &buffer)
        #expect(buffer == [2])

        buffer = []
        File.Watcher.Event.Kind.serialize(.renamed, into: &buffer)
        #expect(buffer == [3])

        buffer = []
        File.Watcher.Event.Kind.serialize(.attributesChanged, into: &buffer)
        #expect(buffer == [4])
    }
}

// MARK: - Options Tests

extension File.Watcher.Test.Unit {
    @Test("Options default values")
    func optionsDefaultValues() {
        let options = File.Watcher.Options()
        #expect(options.recursive == false)
        #expect(options.latency == 0.5)
    }

    @Test("Options custom values")
    func optionsCustomValues() {
        let options = File.Watcher.Options(recursive: true, latency: 1.0)
        #expect(options.recursive == true)
        #expect(options.latency == 1.0)
    }

    @Test("Options latency can be zero")
    func optionsLatencyZero() {
        let options = File.Watcher.Options(latency: 0.0)
        #expect(options.latency == 0.0)
    }

    @Test("Options latency can be large")
    func optionsLatencyLarge() {
        let options = File.Watcher.Options(latency: 60.0)
        #expect(options.latency == 60.0)
    }
}

// MARK: - Edge Cases

extension File.Watcher.Test.EdgeCase {
    @Test("EventType invalid rawValue returns nil")
    func eventTypeInvalidRawValue() {
        #expect(File.Watcher.Event.Kind(rawValue: 255) == nil)
    }

    @Test("EventType boundary rawValue")
    func eventTypeBoundaryRawValue() {
        #expect(File.Watcher.Event.Kind(rawValue: 5) == nil)
    }

    @Test("EventType all invalid rawValues")
    func eventTypeAllInvalidRawValues() {
        for rawValue in UInt8(5)...UInt8(255) {
            #expect(File.Watcher.Event.Kind(rawValue: rawValue) == nil)
        }
    }
}
