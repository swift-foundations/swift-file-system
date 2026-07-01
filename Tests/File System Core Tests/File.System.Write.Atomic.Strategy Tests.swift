//
//  File.System.Write.Atomic.Strategy Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Atomic.Strategy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Strategy.Test.Unit {
    @Test
    func `all cases are distinct`() {
        let allCases: [File.System.Write.Atomic.Strategy] = [.replaceExisting, .noClobber]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test
    func `rawValue for .replaceExisting`() {
        #expect(File.System.Write.Atomic.Strategy.replaceExisting.rawValue == 0)
    }

    @Test
    func `rawValue for .noClobber`() {
        #expect(File.System.Write.Atomic.Strategy.noClobber.rawValue == 1)
    }

    @Test
    func `rawValue round-trip for .replaceExisting`() {
        let strategy = File.System.Write.Atomic.Strategy.replaceExisting
        let restored = File.System.Write.Atomic.Strategy(rawValue: strategy.rawValue)
        #expect(restored == strategy)
    }

    @Test
    func `rawValue round-trip for .noClobber`() {
        let strategy = File.System.Write.Atomic.Strategy.noClobber
        let restored = File.System.Write.Atomic.Strategy(rawValue: strategy.rawValue)
        #expect(restored == strategy)
    }

}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Strategy.Test.EdgeCase {
    @Test
    func `invalid rawValue returns nil`() {
        #expect(File.System.Write.Atomic.Strategy(rawValue: 255) == nil)
    }

    @Test
    func `boundary rawValue (just past valid)`() {
        #expect(File.System.Write.Atomic.Strategy(rawValue: 2) == nil)
    }

    @Test
    func `all invalid rawValues from 2 to 255 return nil`() {
        for rawValue in UInt8(2)...UInt8(255) {
            #expect(File.System.Write.Atomic.Strategy(rawValue: rawValue) == nil)
        }
    }
}
