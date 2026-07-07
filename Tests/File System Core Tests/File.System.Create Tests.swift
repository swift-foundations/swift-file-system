//
//  File.System.Create Tests.swift
//  swift-file-system
//

import Kernel
import Testing

@testable import File_System_Core

extension File.System.Create {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension File.System.Create.Test.Unit {
    // File.System.Create is a namespace with nested types and Options struct

    @Test
    func `Create namespace exists`() {
        _ = File.System.Create.self
        _ = File.System.Create.Directory.self
        _ = File.System.Create.Options.self
    }

    @Test
    func `Options default init`() {
        let options = File.System.Create.Options()
        #expect(options.permissions == nil)
    }

    @Test
    func `Options with permissions`() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o755)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions == permissions)
    }

    @Test
    func `Options permissions can be set`() {
        var options = File.System.Create.Options()
        #expect(options.permissions == nil)

        let permissions = File.System.Metadata.Permissions(rawValue: 0o644)
        options.permissions = permissions
        #expect(options.permissions == permissions)
    }

    @Test
    func `Options is Sendable`() {
        let options = File.System.Create.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Create.Test.`Edge Case` {
    @Test
    func `Options with zero permissions`() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o000)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions?.rawValue == 0)
    }

    @Test
    func `Options with full permissions`() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o777)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions?.rawValue == 0o777)
    }
}
