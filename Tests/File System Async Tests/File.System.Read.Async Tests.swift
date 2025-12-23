//
//  File.System.Read.Async Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System
import StandardsTestSupport
import Testing

@testable import File_System_Async

extension File.System.Read.Async {
    #TestSuites
}

extension File.System.Read.Async.Test.Unit {

    // MARK: - Test Fixtures

    private func createTempFile(content: [UInt8]) throws -> File.Path {
        let path = try File.Path("/tmp/async-stream-test-\(Int.random(in: 0..<Int.max)).bin")
        try File.System.Write.Atomic.write(content.span, to: path)
        return path
    }

    private func cleanup(_ path: File.Path) {
        try? File.System.Delete.delete(at: path)
    }

    // MARK: - Basic Streaming

    @Test("Stream empty file")
    func streamEmptyFile() async throws {
        let io = File.IO.Executor()

        let path = try createTempFile(content: [])
        defer { cleanup(path) }

        let stream = File.System.Read.Async(io: io).bytes(from: path)
        var count = 0

        for try await _ in stream {
            count += 1
        }

        #expect(count == 0)
        await io.shutdown()
    }

    @Test("Stream small file")
    func streamSmallFile() async throws {
        let io = File.IO.Executor()

        let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let stream = File.System.Read.Async(io: io).bytes(from: path)
        var allBytes: [UInt8] = []

        for try await chunk in stream {
            allBytes.append(contentsOf: chunk)
        }

        #expect(allBytes == content)
        await io.shutdown()
    }

    @Test("Stream large file in chunks")
    func streamLargeFileInChunks() async throws {
        let io = File.IO.Executor()

        // Create 1MB file
        let size = 1024 * 1024
        let content = [UInt8](repeating: 42, count: size)
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        // Stream with 64KB chunks (default)
        let stream = File.System.Read.Async(io: io).bytes(from: path)
        var totalBytes = 0
        var chunkCount = 0

        for try await chunk in stream {
            totalBytes += chunk.count
            chunkCount += 1
        }

        #expect(totalBytes == size)
        // Should be ~16 chunks (1MB / 64KB)
        #expect(chunkCount >= 16)
        await io.shutdown()
    }

    @Test("Stream with custom chunk size")
    func streamWithCustomChunkSize() async throws {
        let io = File.IO.Executor()

        // Create 1000 byte file
        let content = [UInt8](repeating: 0xAB, count: 1000)
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        // Stream with 100 byte chunks
        let options = File.System.Read.Async.Options(chunkSize: 100)
        let stream = File.System.Read.Async(io: io).bytes(from: path, options: options)

        var chunkSizes: [Int] = []
        for try await chunk in stream {
            chunkSizes.append(chunk.count)
        }

        // Should be 10 chunks of 100 bytes each
        #expect(chunkSizes.count == 10)
        for size in chunkSizes {
            #expect(size == 100)
        }
        await io.shutdown()
    }

    @Test("Last chunk may be smaller")
    func lastChunkMayBeSmaller() async throws {
        let io = File.IO.Executor()

        // Create 150 byte file
        let content = [UInt8](repeating: 0xCD, count: 150)
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        // Stream with 100 byte chunks
        let options = File.System.Read.Async.Options(chunkSize: 100)
        let stream = File.System.Read.Async(io: io).bytes(from: path, options: options)

        var chunkSizes: [Int] = []
        for try await chunk in stream {
            chunkSizes.append(chunk.count)
        }

        // Should be 2 chunks: 100 + 50
        #expect(chunkSizes.count == 2)
        #expect(chunkSizes[0] == 100)
        #expect(chunkSizes[1] == 50)
        await io.shutdown()
    }

    // MARK: - Error Handling

    @Test("Stream non-existent file throws")
    func streamNonExistentThrows() async throws {
        let io = File.IO.Executor()

        let path = try File.Path("/tmp/nonexistent-\(Int.random(in: 0..<Int.max)).bin")

        let stream = File.System.Read.Async(io: io).bytes(from: path)
        let iterator = stream.makeAsyncIterator()

        do {
            while try await iterator.next() != nil {
                Issue.record("Should throw before yielding")
            }
        } catch {
            // Expected - should throw
            await iterator.terminate()
        }

        await io.shutdown()
    }

    // MARK: - Termination

    @Test("Terminate stops streaming")
    func terminateStopsStreaming() async throws {
        let io = File.IO.Executor()

        // Create 10KB file
        let content = [UInt8](repeating: 0xFF, count: 10 * 1024)
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        // Stream with 1KB chunks
        let options = File.System.Read.Async.Options(chunkSize: 1024)
        let stream = File.System.Read.Async(io: io).bytes(from: path, options: options)
        let iterator = stream.makeAsyncIterator()
        var count = 0

        // Read 3 chunks
        while try await iterator.next() != nil, count < 3 {
            count += 1
        }

        // Terminate
        await iterator.terminate()

        // After termination, next() should return nil
        let afterTerminate = try await iterator.next()
        #expect(afterTerminate == nil)

        await io.shutdown()
    }

    // MARK: - Break from Loop

    @Test("Breaking from loop cleans up resources")
    func breakFromLoopCleansUp() async throws {
        let io = File.IO.Executor()

        // Create 10KB file
        let content = [UInt8](repeating: 0xEE, count: 10 * 1024)
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        // Stream with 1KB chunks
        let options = File.System.Read.Async.Options(chunkSize: 1024)
        let stream = File.System.Read.Async(io: io).bytes(from: path, options: options)
        let iterator = stream.makeAsyncIterator()
        var count = 0

        while try await iterator.next() != nil {
            count += 1
            if count >= 3 {
                break
            }
        }
        await iterator.terminate()

        #expect(count == 3)
        await io.shutdown()
    }

    // MARK: - Data Integrity

    @Test("Streamed content matches original")
    func streamedContentMatchesOriginal() async throws {
        let io = File.IO.Executor()

        // Create file with varied content
        var content: [UInt8] = []
        for i: UInt8 in 0..<255 {
            content.append(contentsOf: [UInt8](repeating: i, count: 100))
        }
        let path = try createTempFile(content: content)
        defer { cleanup(path) }

        let stream = File.System.Read.Async(io: io).bytes(from: path)
        var allBytes: [UInt8] = []

        for try await chunk in stream {
            allBytes.append(contentsOf: chunk)
        }

        #expect(allBytes == content)
        await io.shutdown()
    }
}
