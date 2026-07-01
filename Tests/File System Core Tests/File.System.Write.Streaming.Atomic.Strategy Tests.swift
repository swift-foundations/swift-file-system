//
//  File.System.Write.Streaming.Atomic.Strategy Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Atomic.Strategy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Write.Streaming.Atomic.Strategy.Test.Unit {
    @Test
    func `all cases are distinct`() {
        let allCases: [File.System.Write.Streaming.Atomic.Strategy] = [
            .replaceExisting, .noClobber,
        ]
        #expect(allCases.count == 2)
        #expect(allCases[0] != allCases[1])
    }

    @Test
    func `.replaceExisting case`() {
        let strategy: File.System.Write.Streaming.Atomic.Strategy = .replaceExisting
        if case .replaceExisting = strategy {
            // Success
        } else {
            Issue.record("Expected replaceExisting case")
        }
    }

    @Test
    func `.noClobber case`() {
        let strategy: File.System.Write.Streaming.Atomic.Strategy = .noClobber
        if case .noClobber = strategy {
            // Success
        } else {
            Issue.record("Expected noClobber case")
        }
    }

    @Test
    func `Equatable conformance`() {
        #expect(File.System.Write.Streaming.Atomic.Strategy.replaceExisting == .replaceExisting)
        #expect(File.System.Write.Streaming.Atomic.Strategy.noClobber == .noClobber)
        #expect(File.System.Write.Streaming.Atomic.Strategy.replaceExisting != .noClobber)
    }

    @Test
    func `Strategy is Sendable`() {
        let strategy = File.System.Write.Streaming.Atomic.Strategy.replaceExisting
        Task {
            _ = strategy
        }
    }
}
