//
//  Directory Iteration Performance Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//
//  Regression tests for directory iteration performance.
//  These tests compare sync iteration APIs to establish baseline performance.

import StandardsTestSupport
import Testing
import TestingPerformance

@testable import File_System

#if canImport(Foundation)
import Foundation

/// Performance regression tests for directory iteration.
/// Compares different sync iteration strategies to isolate overhead sources.
@Suite(.serialized)
final class DirectoryIterationPerformanceTests {
    let testDir100Files: File.Path
    let testDir1000Files: File.Path
    
    init() throws {
#if canImport(Foundation)
        let tempDir = try File.Path(NSTemporaryDirectory())
#else
        let tempDir = try File.Path("/tmp")
#endif
        
        let fileData = [UInt8](repeating: 0x00, count: 10)
        let writeOptions = File.System.Write.Atomic.Options(durability: .none)
        
        // Setup: 100 files directory
        self.testDir100Files = File.Path(tempDir, appending: "perf_iter_100_\(Int.random(in: 0..<Int.max))")
        try File.System.Create.Directory.create(at: testDir100Files)
        for i in 0..<100 {
            let filePath = File.Path(testDir100Files, appending: "file_\(i).txt")
            try fileData.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: filePath, options: writeOptions)
            }
        }
        
        // Setup: 1000 files directory
        self.testDir1000Files = File.Path(tempDir, appending: "perf_iter_1000_\(Int.random(in: 0..<Int.max))")
        try File.System.Create.Directory.create(at: testDir1000Files)
        for i in 0..<1000 {
            let filePath = File.Path(testDir1000Files, appending: "file_\(i).txt")
            try fileData.withUnsafeBufferPointer { buffer in
                let span = Span<UInt8>(_unsafeElements: buffer)
                try File.System.Write.Atomic.write(span, to: filePath, options: writeOptions)
            }
        }
    }
    
    deinit {
        try? File.System.Delete.delete(at: testDir100Files, options: .init(recursive: true))
        try? File.System.Delete.delete(at: testDir1000Files, options: .init(recursive: true))
    }
    
    // MARK: - 100 Files Benchmarks
    
    @Test("Sync list (100 files) - returns [Entry]", .timed(iterations: 50, warmup: 5, trackAllocations: false))
    func syncList100() throws {
        let entries = try File.Directory.Contents.list(at: testDir100Files)
        #expect(entries.count == 100)
    }
    
    @Test("Sync names (100 files) - returns [File.Name]", .timed(iterations: 50, warmup: 5, trackAllocations: false))
    func syncNames100() throws {
        let names = try File.Directory.Contents.names(at: testDir100Files)
        #expect(names.count == 100)
    }
    
    @Test("Sync iterator (100 files) - no array allocation", .timed(iterations: 50, warmup: 5, trackAllocations: false))
    func syncIterator100() throws {
        let (iterator, handle) = try File.Directory.Contents.makeIterator(at: testDir100Files)
        defer { File.Directory.Contents.closeIterator(handle) }
        
        var iter = iterator
        var count = 0
        while iter.next() != nil {
            count += 1
        }
        #expect(count == 100)
    }
    
    // MARK: - 1000 Files Benchmarks
    
    @Test("Sync list (1000 files) - returns [Entry]", .timed(iterations: 20, warmup: 3, trackAllocations: false))
    func syncList1000() throws {
        let entries = try File.Directory.Contents.list(at: testDir1000Files)
        #expect(entries.count == 1000)
    }
    
    @Test("Sync names (1000 files) - returns [File.Name]", .timed(iterations: 20, warmup: 3, trackAllocations: false))
    func syncNames1000() throws {
        let names = try File.Directory.Contents.names(at: testDir1000Files)
        #expect(names.count == 1000)
    }
    
    @Test("Sync iterator (1000 files) - no array allocation", .timed(iterations: 20, warmup: 3, trackAllocations: false))
    func syncIterator1000() throws {
        let (iterator, handle) = try File.Directory.Contents.makeIterator(at: testDir1000Files)
        defer { File.Directory.Contents.closeIterator(handle) }
        
        var iter = iterator
        var count = 0
        while iter.next() != nil {
            count += 1
        }
        #expect(count == 1000)
    }
    
    // MARK: - Tight Loop (No Harness Overhead)
    
    @Test("Raw iteration cost - 1000 files × 100 loops")
    func rawIterationCost() throws {
        let loopCount = 100
        let start = Date().timeIntervalSinceReferenceDate
        
        for _ in 0..<loopCount {
            let (iterator, handle) = try File.Directory.Contents.makeIterator(at: testDir1000Files)
            defer { File.Directory.Contents.closeIterator(handle) }
            
            var iter = iterator
            var count = 0
            while iter.next() != nil {
                count += 1
            }
            #expect(count == 1000)
        }
        
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        let totalFiles = loopCount * 1000
        let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("SYNC ITERATOR: \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms")
        print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    @Test("Sync list cost - 1000 files × 100 loops")
    func syncListCost() throws {
        let loopCount = 100
        let start = Date().timeIntervalSinceReferenceDate
        
        for _ in 0..<loopCount {
            let entries = try File.Directory.Contents.list(at: testDir1000Files)
            #expect(entries.count == 1000)
        }
        
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        let totalFiles = loopCount * 1000
        let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("SYNC LIST: \(totalFiles) files in \(String(format: "%.3f", elapsed * 1000))ms")
        print("Per-file: \(String(format: "%.1f", perFileNs)) ns")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

#endif
