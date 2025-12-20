//
//  File.System.Write.Atomic.Commit.Phase Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Commit.Phase {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Commit.Phase.Test.Unit {
    @Test("all cases are distinct")
    func allCasesDistinct() {
        let allCases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory
        ]
        let rawValues = allCases.map(\.rawValue)
        #expect(Set(rawValues).count == allCases.count)
    }

    @Test("rawValue for .pending")
    func rawValuePending() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.rawValue == 0)
    }

    @Test("rawValue for .writing")
    func rawValueWriting() {
        #expect(File.System.Write.Atomic.Commit.Phase.writing.rawValue == 1)
    }

    @Test("rawValue for .syncedFile")
    func rawValueSyncedFile() {
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.rawValue == 2)
    }

    @Test("rawValue for .closed")
    func rawValueClosed() {
        #expect(File.System.Write.Atomic.Commit.Phase.closed.rawValue == 3)
    }

    @Test("rawValue for .renamedPublished")
    func rawValueRenamedPublished() {
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.rawValue == 4)
    }

    @Test("rawValue for .directorySyncAttempted")
    func rawValueDirectorySyncAttempted() {
        #expect(File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.rawValue == 5)
    }

    @Test("rawValue for .syncedDirectory")
    func rawValueSyncedDirectory() {
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.rawValue == 6)
    }

    @Test("published property - false before renamedPublished")
    func publishedPropertyFalse() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.writing.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.published == false)
        #expect(File.System.Write.Atomic.Commit.Phase.closed.published == false)
    }

    @Test("published property - true at and after renamedPublished")
    func publishedPropertyTrue() {
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.published == true)
        #expect(File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.published == true)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.published == true)
    }

    @Test("durabilityAttempted property - false before directorySyncAttempted")
    func durabilityAttemptedFalse() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.writing.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedFile.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.closed.durabilityAttempted == false)
        #expect(File.System.Write.Atomic.Commit.Phase.renamedPublished.durabilityAttempted == false)
    }

    @Test("durabilityAttempted property - true at and after directorySyncAttempted")
    func durabilityAttemptedTrue() {
        #expect(File.System.Write.Atomic.Commit.Phase.directorySyncAttempted.durabilityAttempted == true)
        #expect(File.System.Write.Atomic.Commit.Phase.syncedDirectory.durabilityAttempted == true)
    }

    @Test("Comparable - phases are ordered")
    func comparableOrdered() {
        let phases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory
        ]

        for i in 0..<phases.count - 1 {
            #expect(phases[i] < phases[i + 1])
        }
    }

    @Test("Comparable - equal phases")
    func comparableEqual() {
        let phase1 = File.System.Write.Atomic.Commit.Phase.writing
        let phase2 = File.System.Write.Atomic.Commit.Phase.writing
        #expect(!(phase1 < phase2))
        #expect(!(phase2 < phase1))
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(File.System.Write.Atomic.Commit.Phase.pending == .pending)
        #expect(File.System.Write.Atomic.Commit.Phase.pending != .writing)
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Commit.Phase.Test.EdgeCase {
    @Test("rawValue progression is sequential")
    func rawValueProgression() {
        let phases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory
        ]

        for (index, phase) in phases.enumerated() {
            #expect(phase.rawValue == UInt8(index))
        }
    }

    @Test("first published phase is renamedPublished")
    func firstPublishedPhase() {
        let allPhases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory
        ]

        let firstPublished = allPhases.first { $0.published }
        #expect(firstPublished == .renamedPublished)
    }

    @Test("first durabilityAttempted phase is directorySyncAttempted")
    func firstDurabilityAttemptedPhase() {
        let allPhases: [File.System.Write.Atomic.Commit.Phase] = [
            .pending, .writing, .syncedFile, .closed,
            .renamedPublished, .directorySyncAttempted, .syncedDirectory
        ]

        let firstDurability = allPhases.first { $0.durabilityAttempted }
        #expect(firstDurability == .directorySyncAttempted)
    }
}
