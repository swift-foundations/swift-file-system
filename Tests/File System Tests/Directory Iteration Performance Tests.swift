//
//  Directory Iteration Performance Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//
//  Regression tests for directory iteration performance.
//  These tests compare sync iteration APIs to establish baseline performance.
//
//  Note: Skipped on Windows CI to avoid resource exhaustion.

import Clocks
import File_System_Test_Support
import Formatting
import StandardLibraryExtensions
import StandardsTestSupport
import Testing
import TestingPerformance

@testable import File_System

#if os(macOS) || os(Linux)

    /// Performance regression tests for directory iteration.
    /// Compares different sync iteration strategies to isolate overhead sources.
    @Suite(.serialized)
    final class DirectoryIterationPerformanceTests {

        // MARK: - 100 Files Benchmarks

        @Test(
            "Sync list (100 files) - returns [Entry]",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func syncList100() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<100 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let entries = try File.Directory.Contents.list(at: dir)
                #expect(entries.count == 100)
            }
        }

        @Test(
            "Sync names (100 files) - returns [File.Name]",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func syncNames100() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<100 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let names = try File.Directory.Contents.names(at: dir)
                #expect(names.count == 100)
            }
        }

        @Test(
            "Sync iterator (100 files) - no array allocation",
            .timed(iterations: 50, warmup: 5, trackAllocations: false)
        )
        func syncIterator100() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<100 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let (iterator, handle) = try File.Directory.Contents.makeIterator(at: dir)
                defer { File.Directory.Contents.closeIterator(handle) }

                var iter = iterator
                var count = 0
                while iter.next() != nil {
                    count += 1
                }
                #expect(count == 100)
            }
        }

        // MARK: - 1000 Files Benchmarks

        @Test(
            "Sync list (1000 files) - returns [Entry]",
            .timed(iterations: 20, warmup: 3, trackAllocations: false)
        )
        func syncList1000() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<1000 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let entries = try File.Directory.Contents.list(at: dir)
                #expect(entries.count == 1000)
            }
        }

        @Test(
            "Sync names (1000 files) - returns [File.Name]",
            .timed(iterations: 20, warmup: 3, trackAllocations: false)
        )
        func syncNames1000() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<1000 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let names = try File.Directory.Contents.names(at: dir)
                #expect(names.count == 1000)
            }
        }

        @Test(
            "Sync iterator (1000 files) - no array allocation",
            .timed(iterations: 20, warmup: 3, trackAllocations: false)
        )
        func syncIterator1000() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<1000 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let (iterator, handle) = try File.Directory.Contents.makeIterator(at: dir)
                defer { File.Directory.Contents.closeIterator(handle) }

                var iter = iterator
                var count = 0
                while iter.next() != nil {
                    count += 1
                }
                #expect(count == 1000)
            }
        }

        // MARK: - Tight Loop (No Harness Overhead)

        @Test("Raw iteration cost - 1000 files × 100 loops")
        func rawIterationCost() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<1000 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let loopCount = 100
                let clock = Time.Clock.Continuous()
                let start = clock.now

                for _ in 0..<loopCount {
                    let (iterator, handle) = try File.Directory.Contents.makeIterator(at: dir)
                    defer { File.Directory.Contents.closeIterator(handle) }

                    var iter = iterator
                    var count = 0
                    while iter.next() != nil {
                        count += 1
                    }
                    #expect(count == 1000)
                }

                let elapsed = (clock.now - start).inSeconds
                let totalFiles = loopCount * 1000
                let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print(
                    "SYNC ITERATOR: \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
                )
                print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }

        @Test("Sync list cost - 1000 files × 100 loops")
        func syncListCost() throws {
            try File.Directory.temporary { dir in
                let fileData = [UInt8](repeating: 0x00, count: 10)
                let writeOptions = File.System.Write.Atomic.Options(durability: .none)

                for i in 0..<1000 {
                    let filePath = File.Path(dir.path, appending: "file_\(i).txt")
                    try File.System.Write.Atomic.write(fileData.span, to: filePath, options: writeOptions)
                }

                let loopCount = 100
                let clock = Time.Clock.Continuous()
                let start = clock.now

                for _ in 0..<loopCount {
                    let entries = try File.Directory.Contents.list(at: dir)
                    #expect(entries.count == 1000)
                }

                let elapsed = (clock.now - start).inSeconds
                let totalFiles = loopCount * 1000
                let perFileNs = (elapsed / Double(totalFiles)) * 1_000_000_000

                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print(
                    "SYNC LIST: \(totalFiles) files in \((elapsed * 1000).formatted(.number.precision(3)))ms"
                )
                print("Per-file: \(perFileNs.formatted(.number.precision(1))) ns")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }
    }

#endif
