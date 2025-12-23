//
//  EdgeCase Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Primitives
import File_System_Test_Support
import StandardsTestSupport
import Testing

@testable import File_System_Async

// Note: File.IO #TestSuites declared in Support/Test.swift

extension File.IO.Test.EdgeCase {
    // MARK: - Executor Edge Cases

    @Test("Executor shutdown during idle")
    func executorShutdownIdle() async throws {
        let io = File.IO.Executor()
        await io.shutdown()
        // Should complete without hanging
    }

    @Test("Multiple shutdown calls are safe")
    func multipleShutdown() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Run some work first
            let path = try File.Path("\(dir.path.string)/test-file")
            _ = try await io.run {
                let handle = try File.Handle.open(
                    path,
                    mode: .write,
                    options: [.create, .closeOnExec]
                )
                try handle.close()
            }

            // Multiple shutdowns should be safe
            await io.shutdown()
            await io.shutdown()
            await io.shutdown()
        }
    }

    @Test("Work after shutdown fails gracefully")
    func workAfterShutdown() async throws {
        let io = File.IO.Executor()
        await io.shutdown()

        do {
            _ = try await io.run { 42 }
            Issue.record("Expected error after shutdown")
        } catch {
            // Expected - executor is shut down
        }
    }

    @Test("Rapid executor creation and shutdown")
    func rapidExecutorLifecycle() async throws {
        for _ in 0..<20 {
            let io = File.IO.Executor()
            _ = try await io.run { 1 + 1 }
            await io.shutdown()
        }
    }

    // MARK: - Directory Iteration Edge Cases

    @Test("Iterate directory with many files")
    func manyFiles() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create 100 files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == 100)
            await io.shutdown()
        }
    }

    @Test("Iterate directory that gets modified during iteration")
    func directoryModifiedDuringIteration() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create initial files
            for i in 0..<10 {
                let filePath = try File.Path("\(dir.path.string)/initial-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()
            do {
                while let entry = try await iterator.next() {
                    count += 1
                    // Add new files during iteration (may or may not be seen)
                    if count == 5 {
                        let newPath = try File.Path(
                            "\(dir.path.string)/added-during-\(Int.random(in: 0..<Int.max)).txt"
                        )
                        let handle = try File.Handle.open(newPath, mode: .write, options: [.create, .closeOnExec])
                        try handle.close()
                    }
                    _ = entry
                }
                await iterator.terminate()
            } catch {
                await iterator.terminate()
                throw error
            }

            // Should have iterated at least the original 10
            #expect(count >= 10)
            await io.shutdown()
        }
    }

    @Test("Iterate empty directory")
    func emptyDirectory() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == 0)
            await io.shutdown()
        }
    }

    @Test("Break from iteration early")
    func breakEarly() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create many files
            for i in 0..<50 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
                if count >= 5 {
                    break
                }
            }
            await iterator.terminate()

            #expect(count == 5)
            await io.shutdown()
        }
    }

    @Test("Multiple iterators on same directory")
    func multipleIterators() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create files
            for i in 0..<20 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            // Run two iterations concurrently using TaskGroup with proper cleanup
            let counts = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) {
                group in
                for _ in 0..<2 {
                    group.addTask {
                        var c = 0
                        let entries = File.Directory.Async(io: io).entries(at: dir)
                        let iterator = entries.makeAsyncIterator()
                        do {
                            while try await iterator.next() != nil { c += 1 }
                            await iterator.terminate()
                        } catch {
                            await iterator.terminate()
                            throw error
                        }
                        return c
                    }
                }
                var results: [Int] = []
                for try await count in group {
                    results.append(count)
                }
                return results
            }

            #expect(counts.count == 2)
            for count in counts {
                #expect(count == 20)
            }
            await io.shutdown()
        }
    }

    // MARK: - Walk Edge Cases

    @Test("Walk deeply nested directory")
    func walkDeeplyNested() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create 10 levels of nesting
            var currentPath = dir.path
            for i in 0..<10 {
                let subPath = try File.Path("\(currentPath.string)/level-\(i)")
                try File.System.Create.Directory.create(
                    at: subPath,
                    options: .init(createIntermediates: true)
                )
                // Add a file at each level
                let filePath = try File.Path("\(subPath.string)/file.txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
                currentPath = subPath
            }

            var count = 0
            let walk = File.Directory.Async(io: io).walk(at: dir)
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
            }
            await iterator.terminate()

            // 10 directories + 10 files = 20 entries
            #expect(count == 20)
            await io.shutdown()
        }
    }

    @Test("Walk with symlink cycle - followSymlinks=false")
    func walkSymlinkCycleNoFollow() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create subdirectory
            let subPath = try File.Path("\(dir.path.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to parent (cycle)
            let linkPath = try File.Path("\(subPath.string)/parent-link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: dir.path)

            // Walk without following symlinks - should complete fine
            var count = 0
            let walk = File.Directory.Async(io: io).walk(
                at: dir,
                options: .init(followSymlinks: false)
            )
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
            }
            await iterator.terminate()

            // Should see: subdir + parent-link = 2
            #expect(count == 2)
            await io.shutdown()
        }
    }

    @Test("Walk with symlink cycle - followSymlinks=true detects cycle")
    func walkSymlinkCycleWithFollow() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create subdirectory
            let subPath = try File.Path("\(dir.path.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to parent (cycle)
            let linkPath = try File.Path("\(subPath.string)/parent-link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: dir.path)

            // Create a file so we can verify walk works
            let filePath = try File.Path("\(dir.path.string)/file.txt")
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
            try handle.close()

            // Walk with following symlinks - cycle detection should prevent infinite loop
            var count = 0
            let walk = File.Directory.Async(io: io).walk(
                at: dir,
                options: .init(followSymlinks: true)
            )
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
                // Safety valve - if cycle detection fails, abort
                if count > 100 {
                    Issue.record("Cycle detection failed - infinite loop detected")
                    break
                }
            }
            await iterator.terminate()

            // Should complete without infinite loop
            #expect(count <= 10)  // Reasonable upper bound
            await io.shutdown()
        }
    }

    @Test("Walk non-existent directory fails")
    func walkNonExistent() async throws {
        let io = File.IO.Executor()

        let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

        let walk = File.Directory.Async(io: io).walk(at: File.Directory(path))
        let iterator = walk.makeAsyncIterator()

        do {
            while try await iterator.next() != nil {
                Issue.record("Should not yield anything")
            }
            Issue.record("Should have thrown error")
        } catch {
            // Expected - directory doesn't exist
            await iterator.terminate()
        }

        await io.shutdown()
    }

    @Test("Walk directory with mixed file types")
    func walkMixedTypes() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create regular file
            let filePath = try File.Path("\(dir.path.string)/file.txt")
            let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
            try handle.close()

            // Create subdirectory
            let subPath = try File.Path("\(dir.path.string)/subdir")
            try File.System.Create.Directory.create(at: subPath)

            // Create symlink to file
            let linkPath = try File.Path("\(dir.path.string)/link")
            try File.System.Link.Symbolic.create(at: linkPath, pointingTo: filePath)

            // Create file in subdir
            let subFilePath = try File.Path("\(subPath.string)/nested.txt")
            var subHandle = try File.Handle.open(subFilePath, mode: .write, options: [.create, .closeOnExec])
            try subHandle.close()

            var paths: [String] = []
            let walk = File.Directory.Async(io: io).walk(at: dir)
            let iterator = walk.makeAsyncIterator()
            while let path = try await iterator.next() {
                if let component = path.lastComponent {
                    paths.append(component.string)
                }
            }
            await iterator.terminate()

            #expect(paths.count == 4)
            #expect(paths.contains("file.txt"))
            #expect(paths.contains("subdir"))
            #expect(paths.contains("link"))
            #expect(paths.contains("nested.txt"))
            await io.shutdown()
        }
    }

    // MARK: - Byte Stream Edge Cases

    @Test("Stream empty file")
    func streamEmptyFile() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/empty-file")
            let handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try handle.close()

            var chunks: [[UInt8]] = []
            let stream = File.System.Read.Async(io: io).bytes(from: path)
            for try await chunk in stream {
                chunks.append(chunk)
            }

            #expect(chunks.isEmpty)
            await io.shutdown()
        }
    }

    @Test("Stream file smaller than chunk size")
    func streamSmallFile() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/small-file")
            let data: [UInt8] = [1, 2, 3, 4, 5]
            var handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try handle.write(data.span)
            try handle.close()

            var allBytes: [UInt8] = []
            let stream = File.System.Read.Async(io: io).bytes(
                from: path,
                options: .init(chunkSize: 1024)
            )
            for try await chunk in stream {
                allBytes.append(contentsOf: chunk)
            }

            #expect(allBytes == data)
            await io.shutdown()
        }
    }

    @Test("Stream file with very small chunk size")
    func streamTinyChunks() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/tiny-chunks-file")
            let data: [UInt8] = Array(0..<100)
            var handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try handle.write(data.span)
            try handle.close()

            var chunkCount = 0
            var allBytes: [UInt8] = []
            let stream = File.System.Read.Async(io: io).bytes(from: path, options: .init(chunkSize: 1))
            for try await chunk in stream {
                chunkCount += 1
                allBytes.append(contentsOf: chunk)
            }

            #expect(chunkCount == 100)
            #expect(allBytes == data)
            await io.shutdown()
        }
    }

    @Test("Stream non-existent file fails")
    func streamNonExistent() async throws {
        let io = File.IO.Executor()

        let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

        let stream = File.System.Read.Async(io: io).bytes(from: path)
        let iterator = stream.makeAsyncIterator()

        do {
            while try await iterator.next() != nil {
                Issue.record("Should not yield anything")
            }
            Issue.record("Should have thrown error")
        } catch {
            // Expected - file doesn't exist
            await iterator.terminate()
        }

        await io.shutdown()
    }

    @Test("Break from stream early")
    func breakFromStreamEarly() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/large-file")
            // Create larger file
            let data: [UInt8] = Array(repeating: 42, count: 10000)
            var handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try handle.write(data.span)
            try handle.close()

            var bytesRead = 0
            let stream = File.System.Read.Async(io: io).bytes(
                from: path,
                options: .init(chunkSize: 100)
            )
            let iterator = stream.makeAsyncIterator()
            while let chunk = try await iterator.next() {
                bytesRead += chunk.count
                if bytesRead >= 500 {
                    break
                }
            }
            await iterator.terminate()

            #expect(bytesRead >= 500)
            #expect(bytesRead < 10000)
            await io.shutdown()
        }
    }

    // MARK: - Cancellation Edge Cases

    @Test("Cancel during directory iteration")
    func cancelDuringIteration() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create many files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while try await iterator.next() != nil {
                        count += 1
                        try Task.checkCancellation()
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it a moment to start, then cancel
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()

            do {
                _ = try await task.value
                // May complete before cancellation
            } catch is CancellationError {
                // Expected - raw cancellation from Task.checkCancellation
            } catch let error as File.IO.Error<File.Directory.Iterator.Error> {
                // Expected - wrapped cancellation from iterator
                guard case .cancelled = error else {
                    Issue.record("Expected .cancelled, got \(error)")
                    return
                }
            }

            await io.shutdown()
        }
    }

    @Test("Cancel during walk")
    func cancelDuringWalk() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create some structure
            for i in 0..<5 {
                let subPath = try File.Path("\(dir.path.string)/dir-\(i)")
                try File.System.Create.Directory.create(
                    at: subPath,
                    options: .init(createIntermediates: true)
                )
                for j in 0..<10 {
                    let filePath = try File.Path("\(subPath.string)/file-\(j).txt")
                    let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                    try handle.close()
                }
            }

            let task = Task {
                var count = 0
                let walk = File.Directory.Async(io: io).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                do {
                    while try await iterator.next() != nil {
                        count += 1
                        try Task.checkCancellation()
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it a moment to start, then cancel
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()

            do {
                _ = try await task.value
            } catch is CancellationError {
                // Expected - raw cancellation from Task.checkCancellation
            } catch let error as File.IO.Error<File.Directory.Walk.Error> {
                // Expected - wrapped cancellation from walk iterator
                guard case .cancelled = error else {
                    Issue.record("Expected .cancelled, got \(error)")
                    return
                }
            }

            await io.shutdown()
        }
    }

    @Test("Cancellation within batch - directory entries")
    func cancellationWithinBatch() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create enough files to span multiple batches (batchSize = 64)
            // Create 200 files to ensure we're mid-batch when we cancel
            for i in 0..<200 {
                let filePath = try File.Path("\(dir.path.string)/file-\(padded(i, width: 3)).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while try await iterator.next() != nil {
                        count += 1
                        // Cancel after processing 70 entries (which should be in the middle of second batch)
                        if count == 70 {
                            try Task.checkCancellation()
                        }
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it time to process first batch, then cancel during second batch
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()

            do {
                let count = try await task.value
                // If it completes, it processed everything before cancellation
                #expect(count <= 200)
            } catch is CancellationError {
                // Expected - raw cancellation from Task.checkCancellation
            } catch let error as File.IO.Error<File.Directory.Iterator.Error> {
                // Expected - wrapped cancellation from iterator
                guard case .cancelled = error else {
                    Issue.record("Expected .cancelled, got \(error)")
                    return
                }
            }

            await io.shutdown()
        }
    }

    @Test("Cancellation within batch - directory walk")
    func cancellationWithinBatchWalk() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create structure with enough entries to span multiple batches
            for i in 0..<10 {
                let subPath = try File.Path("\(dir.path.string)/dir-\(i)")
                try File.System.Create.Directory.create(
                    at: subPath,
                    options: .init(createIntermediates: true)
                )
                // 20 files per directory = 200 files + 10 dirs = 210 entries total
                for j in 0..<20 {
                    let filePath = try File.Path("\(subPath.string)/file-\(j).txt")
                    let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                    try handle.close()
                }
            }

            let task = Task {
                var count = 0
                let walk = File.Directory.Async(io: io).walk(at: dir)
                let iterator = walk.makeAsyncIterator()
                do {
                    while try await iterator.next() != nil {
                        count += 1
                        // Cancel after 100 entries (mid-iteration)
                        if count == 100 {
                            try Task.checkCancellation()
                        }
                    }
                    await iterator.terminate()
                } catch {
                    await iterator.terminate()
                    throw error
                }
                return count
            }

            // Give it time to start walking, then cancel
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()

            do {
                let count = try await task.value
                #expect(count <= 210)
            } catch is CancellationError {
                // Expected - raw cancellation from Task.checkCancellation
            } catch let error as File.IO.Error<File.Directory.Walk.Error> {
                // Expected - wrapped cancellation from walk iterator
                guard case .cancelled = error else {
                    Issue.record("Expected .cancelled, got \(error)")
                    return
                }
            }

            await io.shutdown()
        }
    }

    // MARK: - Backpressure Edge Cases

    @Test("Backpressure respected with slow consumer")
    func backpressureRespectedSlowConsumer() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create many files to test backpressure
            for i in 0..<500 {
                let filePath = try File.Path("\(dir.path.string)/file-\(padded(i, width: 4)).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            var processedCount = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            let iterator = entries.makeAsyncIterator()

            // Consume slowly to verify producer doesn't accumulate unbounded batches
            do {
                while try await iterator.next() != nil {
                    processedCount += 1
                    // Add delay to simulate slow consumer
                    try await Task.sleep(for: .milliseconds(1))
                }
                await iterator.terminate()
            } catch {
                await iterator.terminate()
                throw error
            }

            // Should process all files despite slow consumption
            #expect(processedCount == 500)
            // If backpressure wasn't working, memory would grow unboundedly
            // The AsyncThrowingChannel with 1-element buffer ensures bounded memory
            await io.shutdown()
        }
    }

    @Test("Large directory iteration completes - 1000+ files")
    func largeDirectoryIteration() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create 1500 files to verify batching works correctly with large directories
            let fileCount = 1500
            for i in 0..<fileCount {
                let filePath = try File.Path("\(dir.path.string)/file-\(padded(i, width: 4)).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            var count = 0
            let entries = File.Directory.Async(io: io).entries(at: dir)
            for try await _ in entries {
                count += 1
            }

            #expect(count == fileCount)
            await io.shutdown()
        }
    }

    @Test("Large walk completes - 1000+ entries")
    func largeWalkIteration() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create structure with 1000+ entries
            // 25 directories with 40 files each = 1000 files + 25 dirs = 1025 entries
            for i in 0..<25 {
                let subPath = try File.Path("\(dir.path.string)/dir-\(padded(i, width: 2))")
                try File.System.Create.Directory.create(
                    at: subPath,
                    options: .init(createIntermediates: true)
                )
                for j in 0..<40 {
                    let filePath = try File.Path(
                        "\(subPath.string)/file-\(padded(j, width: 2)).txt"
                    )
                    let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                    try handle.close()
                }
            }

            var count = 0
            let walk = File.Directory.Async(io: io).walk(at: dir)
            let iterator = walk.makeAsyncIterator()
            while try await iterator.next() != nil {
                count += 1
            }
            await iterator.terminate()

            #expect(count == 1025)
            await io.shutdown()
        }
    }

    @Test("Directory deleted during iteration")
    func directoryDeletedDuringIteration() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            // Create files
            for i in 0..<100 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                let handle = try File.Handle.open(filePath, mode: .write, options: [.create, .closeOnExec])
                try handle.close()
            }

            let task = Task {
                var count = 0
                let entries = File.Directory.Async(io: io).entries(at: dir)
                let iterator = entries.makeAsyncIterator()
                do {
                    while try await iterator.next() != nil {
                        count += 1
                        // Small delay to allow deletion to happen
                        try await Task.sleep(for: .milliseconds(1))
                    }
                    await iterator.terminate()
                } catch {
                    // May throw error if directory structure changes during iteration
                    // This is acceptable behavior
                    await iterator.terminate()
                }
                return count
            }

            // Give it time to start iterating
            try await Task.sleep(for: .milliseconds(10))

            // Delete some files during iteration
            for i in 50..<75 {
                let filePath = try File.Path("\(dir.path.string)/file-\(i).txt")
                try? File.System.Delete.delete(at: filePath)
            }

            let count = await task.value
            // Count may vary depending on timing of deletion
            // Just verify it doesn't crash or hang
            #expect(count >= 0)
            #expect(count <= 100)
            await io.shutdown()
        }
    }

    // MARK: - Handle Edge Cases

    @Test("Async handle double close")
    func asyncHandleDoubleClose() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/double-close-file")

            let handle = try await File.Handle.Async.open(
                path,
                mode: .write,
                options: [.create, .closeOnExec],
                io: io
            )

            try await handle.close()
            // Second close should be safe
            try await handle.close()
            await io.shutdown()
        }
    }

    @Test("Read from async handle after close fails")
    func readAfterClose() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/read-after-close-file")
            let data: [UInt8] = [1, 2, 3, 4, 5]
            var writeHandle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try writeHandle.write(data.span)
            try writeHandle.close()

            let handle = try await File.Handle.Async.open(path, mode: .read, io: io)

            try await handle.close()

            do {
                _ = try await handle.read(count: 5)
                Issue.record("Should have thrown")
            } catch {
                // Expected
            }
            await io.shutdown()
        }
    }

    // MARK: - System Operation Edge Cases

    @Test("Async exists on non-existent path")
    func asyncExistsNonExistent() async throws {
        let io = File.IO.Executor()

        let path = try File.Path("/tmp/non-existent-\(Int.random(in: 0..<Int.max))")

        let exists = try await io.run { File.System.Stat.exists(at: path) }

        #expect(!exists)
        await io.shutdown()
    }

    @Test("Async stat on symlink")
    func asyncStatSymlink() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let target = try File.Path("\(dir.path.string)/target")
            let link = try File.Path("\(dir.path.string)/link")

            var handle = try File.Handle.open(target, mode: .write, options: [.create, .closeOnExec])
            try handle.write([1, 2, 3].span)
            try handle.close()
            try File.System.Link.Symbolic.create(at: link, pointingTo: target)

            let info = try await io.run { try File.System.Stat.info(at: link) }

            // stat follows symlinks
            #expect(info.type == .regular)
            #expect(info.size == 3)
            await io.shutdown()
        }
    }

    // MARK: - Concurrent Operations

    @Test("Many concurrent file operations")
    func manyConcurrentOps() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<50 {
                    group.addTask {
                        let path = try File.Path("\(dir.path.string)/concurrent-\(i)")

                        var handle = try File.Handle.open(
                            path,
                            mode: .write,
                            options: [.create, .closeOnExec]
                        )
                        let data: [UInt8] = Array(repeating: UInt8(i & 0xFF), count: 100)
                        try handle.write(data.span)
                        try handle.close()

                        let info = try File.System.Stat.info(at: path)
                        #expect(info.size == 100)
                    }
                }

                try await group.waitForAll()
            }
            await io.shutdown()
        }
    }

    @Test("Concurrent reads of same file")
    func concurrentReadsOfSameFile() async throws {
        try await File.Directory.temporary { dir in
            let io = File.IO.Executor()

            let path = try File.Path("\(dir.path.string)/concurrent-read-file")

            // Create file with known content
            let data: [UInt8] = Array(0..<255)
            var handle = try File.Handle.open(path, mode: .write, options: [.create, .closeOnExec])
            try handle.write(data.span)
            try handle.close()

            // Read concurrently
            try await withThrowingTaskGroup(of: [UInt8].self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        var allBytes: [UInt8] = []
                        let stream = File.System.Read.Async(io: io).bytes(from: path)
                        for try await chunk in stream {
                            allBytes.append(contentsOf: chunk)
                        }
                        return allBytes
                    }
                }

                for try await result in group {
                    #expect(result == data)
                }
            }
            await io.shutdown()
        }
    }

}

// Helper for zero-padded numbers (replaces String(format:))
private func padded(_ value: Int, width: Int) -> String {
    let s = String(value)
    if s.count >= width { return s }
    return String(repeating: "0", count: width - s.count) + s
}
