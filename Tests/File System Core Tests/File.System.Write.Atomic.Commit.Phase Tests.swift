//
//  File.System.Write.Atomic.Commit.Phase Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Atomic.Commit.Phase {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Commit.Phase.Test.Unit {
    @Test
    func `all cases are distinct`() {
        let allCases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory,
        ]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test
    func `rawValue for .pending`() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.rawValue == 0)
    }

    @Test
    func `rawValue for .writing`() {
        #expect(File.System.Write.Atomic.Commit.Phase.writing.rawValue == 1)
    }

    @Test
    func `rawValue for .syncedFile`() {
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.rawValue == 2)
    }

    @Test
    func `rawValue for .closed`() {
        #expect(File.System.Write.Atomic.Commit.Phase.closed.rawValue == 3)
    }

    @Test
    func `rawValue for .renamedPublished`() {
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.rawValue == 4)
    }

    @Test
    func `rawValue for .directorySyncAttempted`() {
        #expect(File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.rawValue == 5)
    }

    @Test
    func `rawValue for .syncedDirectory`() {
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.rawValue == 6)
    }

    @Test
    func `published property - false before renamedPublished`() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.writing.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.closed.published == false)
    }

    @Test
    func `published property - true at and after renamedPublished`() {
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.published == true)
        #expect(File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.published == true)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.published == true)
    }

    @Test
    func `durabilityAttempted property - false before directorySyncAttempted`() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.writing.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.closed.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.durabilityAttempted == false)
    }

    @Test
    func `durabilityAttempted property - true at and after directorySyncAttempted`() {
        #expect(
            File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.durabilityAttempted == true
        )
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.durabilityAttempted == true)
    }

    @Test
    func `Comparable - phases are ordered`() {
        let phases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory,
        ]

        for i in 0..<phases.count - 1 {
            #expect(phases[i] < phases[i + 1])
        }
    }

    @Test
    func `Comparable - equal phases`() {
        let phase1 = File.System.Write.Atomic.Commit.Phase.writing
        let phase2 = File.System.Write.Atomic.Commit.Phase.writing
        #expect(!(phase1 < phase2))
        #expect(!(phase2 < phase1))
    }

    @Test
    func `Equatable conformance`() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending == .pending)
        #expect(File.System.Write.Atomic.Commit.Phase.pending != .writing)
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Commit.Phase.Test.EdgeCase {
    @Test
    func `rawValue progression is sequential`() {
        let phases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory,
        ]

        for (index, phase) in phases.enumerated() {
            #expect(phase.rawValue == UInt8(index))
        }
    }

    @Test
    func `first published phase is renamedPublished`() {
        let allPhases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory,
        ]

        let firstPublished = allPhases.first { $0.published }
        #expect(firstPublished == .renamedPublished)
    }

    @Test
    func `first durabilityAttempted phase is directorySyncAttempted`() {
        let allPhases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory,
        ]

        let firstDurability = allPhases.first { $0.durabilityAttempted }
        #expect(firstDurability == .directorySyncAttempted)
    }
}
