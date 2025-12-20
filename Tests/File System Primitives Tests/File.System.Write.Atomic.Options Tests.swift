//
//  File.System.Write.Atomic.Options Tests.swift
//  swift-file-system
//

import StandardsTestSupport
import Testing

@testable import File_System_Primitives

extension File.System.Write.Atomic.Options {
    #TestSuites
}

// MARK: - Unit Tests

extension File.System.Write.Atomic.Options.Test.Unit {
    @Test("default init values")
    func defaultInitValues() {
        let options = File.System.Write.Atomic.Options()

        #expect(options.strategy == .replaceExisting)
        #expect(options.durability == .full)
        #expect(options.preservePermissions == true)
        #expect(options.preserveOwnership == false)
        #expect(options.strictOwnership == false)
        #expect(options.preserveTimestamps == false)
        #expect(options.preserveExtendedAttributes == false)
        #expect(options.preserveACLs == false)
        #expect(options.createIntermediates == false)
    }

    @Test("custom init values")
    func customInitValues() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            durability: .dataOnly,
            preservePermissions: false,
            preserveOwnership: true,
            strictOwnership: true,
            preserveTimestamps: true,
            preserveExtendedAttributes: true,
            preserveACLs: true,
            createIntermediates: true
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .dataOnly)
        #expect(options.preservePermissions == false)
        #expect(options.preserveOwnership == true)
        #expect(options.strictOwnership == true)
        #expect(options.preserveTimestamps == true)
        #expect(options.preserveExtendedAttributes == true)
        #expect(options.preserveACLs == true)
        #expect(options.createIntermediates == true)
    }

    @Test("strategy property is settable")
    func strategyPropertySettable() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.strategy == .replaceExisting)

        options.strategy = .noClobber
        #expect(options.strategy == .noClobber)
    }

    @Test("durability property is settable")
    func durabilityPropertySettable() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.durability == .full)

        options.durability = .none
        #expect(options.durability == .none)
    }

    @Test("preservePermissions property is settable")
    func preservePermissionsSettable() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.preservePermissions == true)

        options.preservePermissions = false
        #expect(options.preservePermissions == false)
    }

    @Test("createIntermediates property is settable")
    func createIntermediatesSettable() {
        var options = File.System.Write.Atomic.Options()
        #expect(options.createIntermediates == false)

        options.createIntermediates = true
        #expect(options.createIntermediates == true)
    }

    @Test("Options is Sendable")
    func optionsIsSendable() {
        let options = File.System.Write.Atomic.Options()
        Task {
            _ = options
        }
    }
}

// MARK: - Edge Cases

extension File.System.Write.Atomic.Options.Test.EdgeCase {
    @Test("all preservation options enabled")
    func allPreservationOptionsEnabled() {
        let options = File.System.Write.Atomic.Options(
            preservePermissions: true,
            preserveOwnership: true,
            strictOwnership: true,
            preserveTimestamps: true,
            preserveExtendedAttributes: true,
            preserveACLs: true
        )

        #expect(options.preservePermissions)
        #expect(options.preserveOwnership)
        #expect(options.strictOwnership)
        #expect(options.preserveTimestamps)
        #expect(options.preserveExtendedAttributes)
        #expect(options.preserveACLs)
    }

    @Test("all preservation options disabled")
    func allPreservationOptionsDisabled() {
        let options = File.System.Write.Atomic.Options(
            preservePermissions: false,
            preserveOwnership: false,
            strictOwnership: false,
            preserveTimestamps: false,
            preserveExtendedAttributes: false,
            preserveACLs: false
        )

        #expect(!options.preservePermissions)
        #expect(!options.preserveOwnership)
        #expect(!options.strictOwnership)
        #expect(!options.preserveTimestamps)
        #expect(!options.preserveExtendedAttributes)
        #expect(!options.preserveACLs)
    }

    @Test("durability none with noClobber")
    func durabilityNoneWithNoClobber() {
        let options = File.System.Write.Atomic.Options(
            strategy: .noClobber,
            durability: .none
        )

        #expect(options.strategy == .noClobber)
        #expect(options.durability == .none)
    }
}
