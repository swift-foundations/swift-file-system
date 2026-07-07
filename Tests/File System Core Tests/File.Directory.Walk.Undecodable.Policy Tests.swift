//
//  File.Directory.Walk.Undecodable.Policy Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.Directory.Walk.Undecodable.Policy {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.Directory.Walk.Undecodable.Policy.Test.Unit {

    // MARK: - Case Existence

    @Test
    func `skip case exists`() {
        let policy: File.Directory.Walk.Undecodable.Policy = .skip
        switch policy {
        case .skip:
            #expect(Bool(true))

        case .emit, .stopAndThrow:
            Issue.record("Expected skip case")
        }
    }

    @Test
    func `emit case exists`() {
        let policy: File.Directory.Walk.Undecodable.Policy = .emit
        switch policy {
        case .emit:
            #expect(Bool(true))

        case .skip, .stopAndThrow:
            Issue.record("Expected emit case")
        }
    }

    @Test
    func `stopAndThrow case exists`() {
        let policy: File.Directory.Walk.Undecodable.Policy = .stopAndThrow
        switch policy {
        case .stopAndThrow:
            #expect(Bool(true))

        case .skip, .emit:
            Issue.record("Expected stopAndThrow case")
        }
    }

    // MARK: - All Cases

    @Test
    func `all three cases are distinct`() {
        let skip: File.Directory.Walk.Undecodable.Policy = .skip
        let emit: File.Directory.Walk.Undecodable.Policy = .emit
        let stop: File.Directory.Walk.Undecodable.Policy = .stopAndThrow

        // Each case should match itself in switch
        var matchCount = 0

        switch skip {
        case .skip: matchCount += 1
        case .emit, .stopAndThrow: break
        }

        switch emit {
        case .emit: matchCount += 1
        case .skip, .stopAndThrow: break
        }

        switch stop {
        case .stopAndThrow: matchCount += 1
        case .skip, .emit: break
        }

        #expect(matchCount == 3)
    }

    @Test
    func `exhaustive switch covers all cases`() {
        let policies: [File.Directory.Walk.Undecodable.Policy] = [.skip, .emit, .stopAndThrow]

        for policy in policies {
            switch policy {
            case .skip:
                #expect(Bool(true))

            case .emit:
                #expect(Bool(true))

            case .stopAndThrow:
                #expect(Bool(true))
            }
        }
    }

    // MARK: - Sendable

    @Test
    func `Policy is Sendable`() async {
        let policy: File.Directory.Walk.Undecodable.Policy = .emit

        let result = await Task {
            policy
        }.value

        switch result {
        case .emit:
            #expect(Bool(true))

        case .skip, .stopAndThrow:
            Issue.record("Expected emit")
        }
    }

    @Test
    func `Policy can be passed across actor boundaries`() async {
        let policies: [File.Directory.Walk.Undecodable.Policy] = [.skip, .emit, .stopAndThrow]

        let results = await Task {
            policies
        }.value

        #expect(results.count == 3)
    }

    // MARK: - Usage Patterns

    @Test
    func `Policy can be stored in array`() {
        let policies: [File.Directory.Walk.Undecodable.Policy] = [.skip, .emit, .stopAndThrow]
        #expect(policies.count == 3)
    }

    @Test
    func `Policy can be used as closure return type`() {
        let handler: () -> File.Directory.Walk.Undecodable.Policy = { .skip }
        let result = handler()
        switch result {
        case .skip:
            #expect(Bool(true))

        case .emit, .stopAndThrow:
            Issue.record("Expected skip")
        }
    }

    @Test
    func `Policy can be returned from function based on condition`() {
        func decidePolicy(shouldEmit: Bool) -> File.Directory.Walk.Undecodable.Policy {
            shouldEmit ? .emit : .skip
        }

        switch decidePolicy(shouldEmit: true) {
        case .emit:
            #expect(Bool(true))

        case .skip, .stopAndThrow:
            Issue.record("Expected emit")
        }

        switch decidePolicy(shouldEmit: false) {
        case .skip:
            #expect(Bool(true))

        case .emit, .stopAndThrow:
            Issue.record("Expected skip")
        }
    }
}

// MARK: - Edge Cases

extension File.Directory.Walk.Undecodable.Policy.Test.`Edge Case` {

    @Test
    func `Policy in optional`() {
        var maybePolicy: File.Directory.Walk.Undecodable.Policy? = nil
        #expect(maybePolicy == nil)

        maybePolicy = .emit
        #expect(maybePolicy != nil)

        if case .emit? = maybePolicy {
            #expect(Bool(true))
        } else {
            Issue.record("Expected emit")
        }
    }

    @Test
    func `Policy in Result type`() {
        let result: Result<File.Directory.Walk.Undecodable.Policy, any Swift.Error> = .success(.skip)

        switch result {
        case .success(let policy):
            switch policy {
            case .skip:
                #expect(Bool(true))

            case .emit, .stopAndThrow:
                Issue.record("Expected skip")
            }

        case .failure:
            Issue.record("Expected success")
        }
    }

    @Test
    func `Policy can be compared using switch`() {
        func describe(_ policy: File.Directory.Walk.Undecodable.Policy) -> Swift.String {
            switch policy {
            case .skip:
                return "skip"

            case .emit:
                return "emit"

            case .stopAndThrow:
                return "stopAndThrow"
            }
        }

        #expect(describe(.skip) == "skip")
        #expect(describe(.emit) == "emit")
        #expect(describe(.stopAndThrow) == "stopAndThrow")
    }

    @Test
    func `Policy default value pattern`() {
        func getPolicy(
            _ override: File.Directory.Walk.Undecodable.Policy? = nil
        ) -> File.Directory.Walk.Undecodable.Policy {
            override ?? .skip  // Default to skip
        }

        switch getPolicy() {
        case .skip:
            #expect(Bool(true))

        case .emit, .stopAndThrow:
            Issue.record("Expected skip as default")
        }

        switch getPolicy(.emit) {
        case .emit:
            #expect(Bool(true))

        case .skip, .stopAndThrow:
            Issue.record("Expected emit as override")
        }
    }
}
