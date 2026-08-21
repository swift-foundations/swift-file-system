import Kernel
import Testing

@testable import File_System_Core

extension File.System.Write.Streaming.Direct.Strategy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Write.Streaming.Direct.Strategy.Test.Unit {
    @Test
    func `all cases are distinct`() {
        let allCases: [File.System.Write.Streaming.Direct.Strategy] = [
            .create, .truncate,
        ]
        #expect(allCases.count == 2)
        #expect(allCases[0] != allCases[1])
    }

    @Test
    func `.create case`() {
        let strategy: File.System.Write.Streaming.Direct.Strategy = .create
        if case .create = strategy {

        } else {
            Issue.record("Expected create case")
        }
    }

    @Test
    func `.truncate case`() {
        let strategy: File.System.Write.Streaming.Direct.Strategy = .truncate
        if case .truncate = strategy {

        } else {
            Issue.record("Expected truncate case")
        }
    }

    @Test
    func `Equatable conformance`() {
        #expect(File.System.Write.Streaming.Direct.Strategy.create == .create)
        #expect(File.System.Write.Streaming.Direct.Strategy.truncate == .truncate)
        #expect(File.System.Write.Streaming.Direct.Strategy.create != .truncate)
    }

    @Test
    func `Strategy is Sendable`() {
        let strategy = File.System.Write.Streaming.Direct.Strategy.create
        Task {
            _ = strategy
        }
    }
}
