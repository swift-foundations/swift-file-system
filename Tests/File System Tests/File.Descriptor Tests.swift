//
//  File.Descriptor+Convenience Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System

extension File.Descriptor {
    #TestSuites
}

extension File.Descriptor.Test.Unit {

    // MARK: - withOpen

    @Test("withOpen opens and closes descriptor")
    func withOpenOpensAndCloses() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var wasValid = false

            try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
                wasValid = descriptor.isValid
            }

            #expect(wasValid == true)
        }
    }

    @Test("withOpen returns closure result")
    func withOpenReturnsResult() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let result = try File.Descriptor.withOpen(filePath, mode: .read) { _ in
                return 42
            }

            #expect(result == 42)
        }
    }

    @Test("withOpen closes descriptor after normal completion")
    func withOpenClosesAfterCompletion() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            // After withOpen completes, the descriptor should be closed
            // We verify this by being able to open it again
            _ = try File.Descriptor.withOpen(filePath, mode: .read) { _ in }

            // If descriptor wasn't closed, this might fail
            let result = try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
                descriptor.isValid
            }

            #expect(result == true)
        }
    }

    @Test("withOpen closes descriptor after error")
    func withOpenClosesAfterError() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            struct TestError: Error {}

            // The descriptor should be closed even if the closure throws
            do {
                try File.Descriptor.withOpen(filePath, mode: .read) { _ in
                    throw TestError()
                }
                Issue.record("Expected error to be thrown")
            } catch is TestError {
                // Expected
            }

            // Verify descriptor was closed by opening successfully again
            let result = try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
                descriptor.isValid
            }
            #expect(result == true)
        }
    }

    @Test("withOpen propagates open error")
    func withOpenPropagatesOpenError() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "non-existent.txt")

            #expect(throws: File.Descriptor.Error.self) {
                try File.Descriptor.withOpen(filePath, mode: .read) { _ in
                    // Should never reach here
                }
            }
        }
    }

    @Test("withOpen with create option creates file")
    func withOpenCreatesFile() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "new-file.txt")
            #expect(!File.System.Stat.exists(at: filePath))

            let wasValid = try File.Descriptor.withOpen(filePath, mode: .write, options: [.create]) {
                descriptor in
                descriptor.isValid
            }
            #expect(wasValid)

            #expect(File.System.Stat.exists(at: filePath))
        }
    }

    // MARK: - Async withOpen

    @Test("async withOpen opens and closes descriptor")
    func asyncWithOpenOpensAndCloses() async throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            var wasValid = false

            try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
                wasValid = descriptor.isValid
            }

            #expect(wasValid == true)
        }
    }

    @Test("async withOpen with async body")
    func asyncWithOpenAsyncBody() async throws {
        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let result = try await File.Descriptor.withOpen(filePath, mode: .read) {
                descriptor async throws in
                // Simulate async work
                try await Task.sleep(for: .milliseconds(1))
                return descriptor.isValid
            }

            #expect(result == true)
        }
    }

    @Test("async withOpen closes after error")
    func asyncWithOpenClosesAfterError() async throws {
        try await File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            struct TestError: Error {}

            do {
                try await File.Descriptor.withOpen(filePath, mode: .read) { _ async throws in
                    throw TestError()
                }
                Issue.record("Expected error to be thrown")
            } catch is TestError {
                // Expected
            }

            // Verify can open again
            let result = try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
                descriptor.isValid
            }
            #expect(result == true)
        }
    }

    // MARK: - duplicated

    @Test("duplicated returns valid descriptor")
    func duplicatedReturnsValidDescriptor() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let wasValid = try File.Descriptor.withOpen(filePath, mode: .read) { original in
                let duplicate = try original.duplicated()
                let valid = duplicate.isValid
                try duplicate.close()
                return valid
            }
            #expect(wasValid == true)
        }
    }

    @Test("duplicated creates independent descriptor")
    func duplicatedCreatesIndependentDescriptor() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let (originalValid, duplicateValid, differentRawValues) = try File.Descriptor.withOpen(
                filePath,
                mode: .read
            ) { original in
                let duplicate = try original.duplicated()

                let origValid = original.isValid
                let dupValid = duplicate.isValid
                let different = original.rawValue != duplicate.rawValue

                try duplicate.close()

                return (origValid, dupValid, different)
            }

            #expect(originalValid == true)
            #expect(duplicateValid == true)
            #expect(differentRawValues == true)
        }
    }

    @Test("closing duplicate doesn't affect original")
    func closingDuplicateDoesntAffectOriginal() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let originalStillValid = try File.Descriptor.withOpen(filePath, mode: .read) {
                original in
                let duplicate = try original.duplicated()
                try duplicate.close()

                // Original should still be valid after closing duplicate
                return original.isValid
            }
            #expect(originalStillValid == true)
        }
    }

    // MARK: - .open namespace

    @Test("open.read opens descriptor for reading")
    func openReadOpensDescriptor() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let wasValid = try File.Descriptor.open(filePath).read { descriptor in
                descriptor.isValid
            }

            #expect(wasValid == true)
        }
    }

    @Test("open.write opens for writing")
    func openWriteOpensForWriting() throws {
        try File.Directory.temporary { dir in
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let wasValid = try File.Descriptor.open(filePath).write { descriptor in
                descriptor.isValid
            }

            #expect(wasValid == true)
        }
    }

    @Test("open.readWrite opens for read and write")
    func openReadWriteOpensForReadAndWrite() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = File.Path(dir.path, appending: "test-file.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let wasValid = try File.Descriptor.open(filePath).readWrite { descriptor in
                descriptor.isValid
            }

            #expect(wasValid == true)
        }
    }
}
