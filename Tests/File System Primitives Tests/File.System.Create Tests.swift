//
//  File.System.Create Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Create {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Create.Test.Unit {
    // File.System.Create is a namespace with nested types and Options struct

    @Test("Create namespace exists")
    func createNamespaceExists() {
        _ = File.System.Create.self
        _ = File.System.Create.Directory.self
        _ = File.System.Create.File.self
        _ = File.System.Create.Options.self
    }

    @Test("Options default init")
    func optionsDefaultInit() {
        let options = File.System.Create.Options()
        #expect(options.permissions == nil)
    }

    @Test("Options with permissions")
    func optionsWithPermissions() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o755)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions == permissions)
    }

    @Test("Options permissions can be set")
    func optionsPermissionsCanBeSet() {
        var options = File.System.Create.Options()
        #expect(options.permissions == nil)

        let permissions = File.System.Metadata.Permissions(rawValue: 0o644)
        options.permissions = permissions
        #expect(options.permissions == permissions)
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options = File.System.Create.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Create.Test.EdgeCase {
    @Test("Options with zero permissions")
    func optionsWithZeroPermissions() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o000)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions?.rawValue == 0)
    }

    @Test("Options with full permissions")
    func optionsWithFullPermissions() {
        let permissions = File.System.Metadata.Permissions(rawValue: 0o777)
        let options = File.System.Create.Options(permissions: permissions)
        #expect(options.permissions?.rawValue == 0o777)
    }
}
