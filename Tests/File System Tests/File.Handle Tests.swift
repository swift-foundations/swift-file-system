//
//  File.Handle+Convenience Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import StandardsTestSupport
import Testing
import File_System_Test_Support

@testable import File_System

extension File.Handle {
    #TestSuites
}

extension File.Handle.Test.Unit {

    // MARK: - withOpen

    @Test("withOpen reads file content")
    func withOpenReadsContent() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readData = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.read(count: 10)
            }

            #expect(readData == content)
        }
    }

    @Test("withOpen writes file content")
    func withOpenWritesContent() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let dataToWrite: [UInt8] = [10, 20, 30, 40, 50]

            try File.Handle.withOpen(filePath, mode: .write, options: [.truncate]) { handle throws(File.Handle.Error) in
                try handle.write(dataToWrite.span)
            }

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack == dataToWrite)
        }
    }

    @Test("withOpen closes handle after normal completion")
    func withOpenClosesHandleNormally() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            // After withOpen completes, the handle should be closed
            // We verify this by being able to open it again
            _ = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.read(count: 3)
            }

            // If handle wasn't closed, this might fail or behave unexpectedly
            let secondRead = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.read(count: 3)
            }

            #expect(secondRead == content)
        }
    }

    @Test("withOpen closes handle after error")
    func withOpenClosesHandleAfterError() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            // The handle should be closed even if the closure throws
            do throws(File.Handle.Error) {
                try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                    // Trigger a handle error by seeking beyond valid range
                    _ = try handle.seek(to: -1, from: .start)
                }
                Issue.record("Expected error to be thrown")
            } catch {
                // Error is File.Handle.Error (typed throws)
                guard case .seekFailed(let offset, let origin, _, _) = error else {
                    Issue.record("Expected .seekFailed, got \(error)")
                    return
                }
                #expect(offset == -1)
                #expect(origin == .start)
            }

            // Verify handle was closed by opening successfully again
            let result = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.read(count: 10)
            }
            #expect(result.isEmpty)
        }
    }

    @Test("withOpen returns closure result")
    func withOpenReturnsResult() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let sum = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                let bytes = try handle.read(count: 10)
                return bytes.reduce(0, +)
            }

            #expect(sum == 55)  // 1+2+3+4+5+6+7+8+9+10
        }
    }

    @Test("withOpen with create option creates file")
    func withOpenCreatesFile() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/create.txt")
            #expect(!File.System.Stat.exists(at: filePath))

            try File.Handle.withOpen(filePath, mode: .write, options: [.create]) { handle throws(File.Handle.Error) in
                let bytes: [UInt8] = [72, 105]  // "Hi"
                try handle.write(bytes.span)
            }

            #expect(File.System.Stat.exists(at: filePath))
        }
    }

    @Test("withOpen propagates open error")
    func withOpenPropagatesOpenError() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/non-existent.txt")

            do throws(File.Handle.Error) {
                try File.Handle.withOpen(filePath, mode: .read) { _ throws(File.Handle.Error) in
                    // Should never reach here
                }
                Issue.record("Expected error to be thrown")
            } catch {
                // Error is File.Handle.Error (typed throws)
                #expect(error == .pathNotFound(filePath))
            }
        }
    }

    // MARK: - rewind

    @Test("rewind seeks to beginning")
    func rewindSeeksToBeginning() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let result = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                // Read some data
                _ = try handle.read(count: 3)

                // Rewind to beginning
                let position = try handle.rewind()
                #expect(position == 0)

                // Read from beginning again
                return try handle.read(count: 5)
            }

            #expect(result == content)
        }
    }

    @Test("rewind returns zero position")
    func rewindReturnsZero() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let position = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                // Seek to middle
                _ = try handle.seek(to: 3, from: .start)

                // Rewind and check position
                return try handle.rewind()
            }

            #expect(position == 0)
        }
    }

    // MARK: - seekToEnd

    @Test("seekToEnd returns file size")
    func seekToEndReturnsFileSize() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let size = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.seekToEnd()
            }

            #expect(size == 10)
        }
    }

    @Test("seekToEnd on empty file returns zero")
    func seekToEndOnEmptyFile() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let size = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.seekToEnd()
            }

            #expect(size == 0)
        }
    }

    @Test("seekToEnd then rewind allows re-read")
    func seekToEndThenRewindAllowsReRead() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [10, 20, 30]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let result = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                // Seek to end
                let size = try handle.seekToEnd()
                #expect(size == 3)

                // Rewind
                try handle.rewind()

                // Read all content
                return try handle.read(count: Int(size))
            }

            #expect(result == content)
        }
    }

    // MARK: - Async withOpen

    @Test("async withOpen reads file content")
    func asyncWithOpenReadsContent() async throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readData = try File.Handle.withOpen(filePath, mode: .read) { handle throws(File.Handle.Error) in
                try handle.read(count: 10)
            }

            #expect(readData == content)
        }
    }

    @Test("async withOpen with async body")
    func asyncWithOpenAsyncBody() async throws {
        try await File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let result = try await File.Handle.withOpen(filePath, mode: .read) {
                handle async throws(File.Handle.Error) in
                // Read file content asynchronously
                return try handle.read(count: 10)
            }

            #expect(result == content)
        }
    }

    // MARK: - .open namespace

    @Test("open.read reads file")
    func openReadReadsFile() throws {
        try File.Directory.temporary { dir in
            let content: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(content.span, to: filePath)

            let readData = try File.Handle.open(filePath).read { handle throws(File.Handle.Error) in
                try handle.read(count: 10)
            }

            #expect(readData == content)
        }
    }

    @Test("open.write writes to file")
    func openWriteWritesToFile() throws {
        try File.Directory.temporary { dir in
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write([UInt8]().span, to: filePath)

            let dataToWrite: [UInt8] = [100, 200]

            try File.Handle.open(filePath, options: [.truncate]).write { handle throws(File.Handle.Error) in
                try handle.write(dataToWrite.span)
            }

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack == dataToWrite)
        }
    }

    @Test("open.appending appends to file")
    func openAppendingAppendsToFile() throws {
        try File.Directory.temporary { dir in
            let initialContent: [UInt8] = [1, 2, 3]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(initialContent.span, to: filePath)

            let dataToAppend: [UInt8] = [4, 5, 6]

            try File.Handle.open(filePath).appending { handle throws(File.Handle.Error) in
                try handle.write(dataToAppend.span)
            }

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack == [1, 2, 3, 4, 5, 6])
        }
    }

    @Test("open.readWrite allows read and write")
    func openReadWriteAllowsReadAndWrite() throws {
        try File.Directory.temporary { dir in
            let initialContent: [UInt8] = [1, 2, 3, 4, 5]
            let filePath = try File.Path(dir.path.string + "/test.bin")
            try File.System.Write.Atomic.write(initialContent.span, to: filePath)

            let result = try File.Handle.open(filePath).readWrite { handle throws(File.Handle.Error) in
                // Read first
                let data = try handle.read(count: 3)
                // Seek back
                try handle.rewind()
                // Write
                let newData: [UInt8] = [10, 20, 30]
                try handle.write(newData.span)
                return data
            }

            #expect(result == [1, 2, 3])

            let readBack = try File.System.Read.Full.read(from: filePath)
            #expect(readBack == [10, 20, 30, 4, 5])
        }
    }
}
