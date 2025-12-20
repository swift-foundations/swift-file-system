//
//  File.Handle.Options Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.Handle.Options {
    #TestSuites
}

// MARK: - Unit Tests

extension File.Handle.Options.Test.Unit {
    @Test("init with rawValue")
    func initWithRawValue() {
        let options = File.Handle.Options(rawValue: 5)
        #expect(options.rawValue == 5)
    }

    @Test(".create option")
    func createOption() {
        let options = File.Handle.Options.create
        #expect(options.rawValue == 1 << 0)
        #expect(options.rawValue == 1)
    }

    @Test(".truncate option")
    func truncateOption() {
        let options = File.Handle.Options.truncate
        #expect(options.rawValue == 1 << 1)
        #expect(options.rawValue == 2)
    }

    @Test(".exclusive option")
    func exclusiveOption() {
        let options = File.Handle.Options.exclusive
        #expect(options.rawValue == 1 << 2)
        #expect(options.rawValue == 4)
    }

    @Test(".noFollow option")
    func noFollowOption() {
        let options = File.Handle.Options.noFollow
        #expect(options.rawValue == 1 << 3)
        #expect(options.rawValue == 8)
    }

    @Test(".closeOnExec option")
    func closeOnExecOption() {
        let options = File.Handle.Options.closeOnExec
        #expect(options.rawValue == 1 << 4)
        #expect(options.rawValue == 16)
    }

    @Test("combining options with union")
    func combiningOptionsWithUnion() {
        let options: File.Handle.Options = [.create, .truncate]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(!options.contains(.exclusive))
        #expect(options.rawValue == 3)
    }

    @Test("all options are distinct")
    func allOptionsDistinct() {
        let allOptions: [File.Handle.Options] = [
            .create, .truncate, .exclusive, .noFollow, .closeOnExec
        ]
        let rawValues = allOptions.map(\.rawValue)
        #expect(Set(rawValues).count == allOptions.count)
    }

    @Test("combining all options")
    func combiningAllOptions() {
        let options: File.Handle.Options = [
            .create, .truncate, .exclusive, .noFollow, .closeOnExec
        ]
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
        #expect(options.contains(.exclusive))
        #expect(options.contains(.noFollow))
        #expect(options.contains(.closeOnExec))
        #expect(options.rawValue == 31) // 1 + 2 + 4 + 8 + 16
    }

    @Test("Binary.Serializable - serialize produces correct bytes")
    func binarySerialize() {
        var buffer: [UInt8] = []
        File.Handle.Options.serialize(.create, into: &buffer)
        // UInt32 in little-endian: 1 = [1, 0, 0, 0]
        #expect(buffer.count == 4)
        #expect(buffer[0] == 1)
    }
}

// MARK: - Edge Cases

extension File.Handle.Options.Test.EdgeCase {
    @Test("empty options")
    func emptyOptions() {
        let options: File.Handle.Options = []
        #expect(options.rawValue == 0)
        #expect(!options.contains(.create))
        #expect(!options.contains(.truncate))
    }

    @Test("options equality")
    func optionsEquality() {
        let options1: File.Handle.Options = [.create, .truncate]
        let options2: File.Handle.Options = [.truncate, .create]
        #expect(options1 == options2)
    }

    @Test("options inequality")
    func optionsInequality() {
        let options1: File.Handle.Options = [.create]
        let options2: File.Handle.Options = [.truncate]
        #expect(options1 != options2)
    }

    @Test("inserting option")
    func insertingOption() {
        var options: File.Handle.Options = [.create]
        options.insert(.truncate)
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
    }

    @Test("removing option")
    func removingOption() {
        var options: File.Handle.Options = [.create, .truncate]
        options.remove(.truncate)
        #expect(options.contains(.create))
        #expect(!options.contains(.truncate))
    }

    @Test("intersection of options")
    func intersectionOfOptions() {
        let options1: File.Handle.Options = [.create, .truncate]
        let options2: File.Handle.Options = [.truncate, .exclusive]
        let intersection = options1.intersection(options2)
        #expect(intersection == .truncate)
    }

    @Test("symmetric difference of options")
    func symmetricDifferenceOfOptions() {
        let options1: File.Handle.Options = [.create, .truncate]
        let options2: File.Handle.Options = [.truncate, .exclusive]
        let diff = options1.symmetricDifference(options2)
        #expect(diff.contains(.create))
        #expect(diff.contains(.exclusive))
        #expect(!diff.contains(.truncate))
    }
}
