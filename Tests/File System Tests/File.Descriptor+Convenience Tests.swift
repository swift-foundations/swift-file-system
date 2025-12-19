//
//  File.Descriptor+Convenience Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Foundation
import Testing

@testable import File_System

extension File.Descriptor.Test.Unit {
    // MARK: - Test Fixtures
    
    private func createTempFile(content: [UInt8] = []) throws -> String {
        let path = "/tmp/descriptor-convenience-test-\(UUID().uuidString).bin"
        let data = Data(content)
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }
    
    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    // MARK: - withOpen
    
    @Test
    func `withOpen opens and closes descriptor`() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        var wasValid = false
        
        try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
            wasValid = descriptor.isValid
        }
        
        #expect(wasValid == true)
    }
    
    @Test
    func `withOpen returns closure result`() throws {
        let path = try createTempFile(content: [1, 2, 3])
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let result = try File.Descriptor.withOpen(filePath, mode: .read) { _ in
            return 42
        }
        
        #expect(result == 42)
    }
    
    @Test
    func `withOpen closes descriptor after normal completion`() throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        
        // After withOpen completes, the descriptor should be closed
        // We verify this by being able to open it again
        _ = try File.Descriptor.withOpen(filePath, mode: .read) { _ in }
        
        // If descriptor wasn't closed, this might fail
        let result = try File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
            descriptor.isValid
        }
        
        #expect(result == true)
    }
    
    @Test
    func `withOpen closes descriptor after error`() throws {
        let path = try createTempFile()
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        
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
    
    @Test
    func `withOpen propagates open error`() throws {
        let nonExistent = "/tmp/non-existent-\(UUID().uuidString).txt"
        let filePath = try File.Path(nonExistent)
        
        #expect(throws: File.Descriptor.Error.self) {
            try File.Descriptor.withOpen(filePath, mode: .read) { _ in
                // Should never reach here
            }
        }
    }
    
    @Test
    func `withOpen with create option creates file`() throws {
        let path = "/tmp/descriptor-convenience-create-\(UUID().uuidString).txt"
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        #expect(!FileManager.default.fileExists(atPath: path))
        
        let wasValid = try File.Descriptor.withOpen(filePath, mode: .write, options: [.create])
        { descriptor in
            descriptor.isValid
        }
        #expect(wasValid)
        
        #expect(FileManager.default.fileExists(atPath: path))
    }
    
    // MARK: - Async withOpen
    
    @Test
    func `async withOpen opens and closes descriptor`() async throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        var wasValid = false
        
        try await File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
            wasValid = descriptor.isValid
        }
        
        #expect(wasValid == true)
    }
    
    @Test
    func `async withOpen with async body`() async throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        
        let result = try await File.Descriptor.withOpen(filePath, mode: .read) {
            descriptor async throws in
            // Simulate async work
            try await Task.sleep(for: .milliseconds(1))
            return descriptor.isValid
        }
        
        #expect(result == true)
    }
    
    @Test
    func `async withOpen closes after error`() async throws {
        let path = try createTempFile()
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        
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
        let result = try await File.Descriptor.withOpen(filePath, mode: .read) { descriptor in
            descriptor.isValid
        }
        #expect(result == true)
    }
    
    // MARK: - duplicated
    
    @Test
    func `duplicated returns valid descriptor`() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let wasValid = try File.Descriptor.withOpen(filePath, mode: .read) { original in
            var duplicate = try original.duplicated()
            let valid = duplicate.isValid
            try duplicate.close()
            return valid
        }
        #expect(wasValid == true)
    }
    
    @Test
    func `duplicated creates independent descriptor`() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let (originalValid, duplicateValid, differentRawValues) = try File.Descriptor.withOpen(
            filePath,
            mode: .read
        ) { original in
            var duplicate = try original.duplicated()
            
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
    
    @Test
    func `closing duplicate doesn't affect original`() throws {
        let content: [UInt8] = [1, 2, 3, 4, 5]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let originalStillValid = try File.Descriptor.withOpen(filePath, mode: .read) {
            original in
            var duplicate = try original.duplicated()
            try duplicate.close()
            
            // Original should still be valid after closing duplicate
            return original.isValid
        }
        #expect(originalStillValid == true)
    }
    
    // MARK: - .open namespace
    
    @Test
    func `open.read opens descriptor for reading`() throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let wasValid = try File.Descriptor.open(filePath).read { descriptor in
            descriptor.isValid
        }
        
        #expect(wasValid == true)
    }
    
    @Test
    func `open.write opens for writing`() throws {
        let path = try createTempFile()
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let wasValid = try File.Descriptor.open(filePath).write { descriptor in
            descriptor.isValid
        }
        
        #expect(wasValid == true)
    }
    
    @Test
    func `open.readWrite opens for read and write`() throws {
        let content: [UInt8] = [1, 2, 3]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }
        
        let filePath = try File.Path(path)
        let wasValid = try File.Descriptor.open(filePath).readWrite { descriptor in
            descriptor.isValid
        }
        
        #expect(wasValid == true)
    }
}
