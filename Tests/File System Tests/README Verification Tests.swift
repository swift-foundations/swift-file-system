////
////  README Verification Tests.swift
////  swift-file-system
////
////  Tests that verify all README code examples compile correctly.
////
//
//import File_System
//import File_System_Test_Support
//import Testing
//
///// Tests verifying README examples compile and work correctly.
/////
///// Each test corresponds to a code example in the README.
///// The goal is compilation verification - if this file compiles,
///// the README examples are valid.
//@Suite("README Verification")
//struct README_Verification_Tests {
//
//    // MARK: - Quick Start: File Operations
//
//    @Test("Quick Start - File Operations")
//    func quickStartFileOperations() throws {
//        try File.Directory.temporary { dir in
//            // Create a file reference
//            let file = File(dir, appending: "data.txt")
//
//            // Read and write (sync)
//            try file.write("Hello, World!")
//            let data = try file.read()
//            #expect(data.count > 0)
//
//            // Append
//            try file.append(" More content")
//
//            // Check properties
//            #expect(file.exists)
//            #expect(file.isFile)
//            _ = try file.size
//            _ = try file.isEmpty
//
//            // File operations
//            let otherFile = File(dir, appending: "other.txt")
//            try file.copy(to: otherFile)
//
//            let newLocation = File(dir, appending: "moved.txt")
//            try otherFile.move(to: newLocation)
//
//            try newLocation.delete()
//        }
//    }
//
//    @Test("Quick Start - File Operations (async)")
//    func quickStartFileOperationsAsync() async throws {
//        try await File.Directory.temporary { dir in
//            let file = File(dir, appending: "data.txt")
//
//            // Read and write (async)
//            try await file.write("Hello, World!")
//            let data = try await file.read()
//            #expect(data.count > 0)
//        }
//    }
//
//    // MARK: - Quick Start: Low-Level Handle Access
//
//    @Test("Quick Start - Low-Level Handle Access")
//    func quickStartHandleAccess() throws {
//        try File.Directory.temporary { dir in
//            let file = File(dir, appending: "handle-test.txt")
//            try file.write("Some initial content for handle testing")
//
//            // Scoped handle access with automatic cleanup
//            try file.open { handle in
//                let chunk = try handle.read(count: 1024)
//                #expect(chunk.count > 0)
//            }
//
//            // Write handle access
//            let bytes: [UInt8] = [72, 101, 108, 108, 111] // "Hello"
//            try file.open.write { handle in
//                try handle.write(bytes)
//            }
//
//            // Static API with readWrite
//            let path = file.path
//            let data: [UInt8] = [87, 111, 114, 108, 100] // "World"
//            try File.open(path).readWrite { handle in
//                try handle.seek(to: 100)
//                try handle.write(data)
//            }
//        }
//    }
//
//    // MARK: - Quick Start: Directory Operations
//
//    @Test("Quick Start - Directory Operations")
//    func quickStartDirectoryOperations() throws {
//        try File.Directory.temporary { baseDir in
//            let dir = File.Directory(baseDir, appending: "mydir")
//
//            // Create and delete
//            try dir.create(recursive: true)
//
//            // Create some content first
//            let testFile = File(dir.path, appending: "test.txt")
//            try testFile.write("test")
//
//            // Contents
//            for entry in try dir.contents() {
//                _ = entry.name
//            }
//
//            // Subscript access
//            let readme = dir[file: "README.md"]
//            let subdir = dir[directory: "src"]
//            _ = readme
//            _ = subdir
//
//            // Recursive walk (sync)
//            for entry in try File.Directory.Walk(at: dir.path) {
//                _ = entry.depth
//                _ = entry.path
//            }
//
//            try dir.delete(recursive: true)
//        }
//    }
//
//    @Test("Quick Start - Directory Operations (async)")
//    func quickStartDirectoryOperationsAsync() async throws {
//        try await File.Directory.temporary { baseDir in
//            let dir = File.Directory(baseDir, appending: "mydir")
//            try await File.System.Create.Directory.create(at: dir.path)
//
//            // Create some content
//            let testFile = File(dir.path, appending: "test.txt")
//            try await testFile.write("test")
//
//            // Async iteration (batched)
//            for try await entry in File.Directory.entries(at: dir.path) {
//                _ = entry.name
//            }
//
//            try await File.System.Delete.delete(at: dir.path, options: .init(recursive: true))
//        }
//    }
//
//    // MARK: - Sync and Async - Same API
//
//    @Test("Sync and Async - Same API")
//    func syncAndAsyncSameAPI() throws {
//        try File.Directory.temporary { dir in
//            let file = File(dir, appending: "sync-async.txt")
//            let path = file.path
//            let data: [UInt8] = Array("Test content".utf8)
//
//            // Convenience API (sync)
//            try file.write(data)
//            let readData = try file.read()
//            #expect(readData == data)
//
//            // Primitive API (sync)
//            try File.System.Write.Atomic.write(data, to: path, options: .init(durability: .full))
//        }
//    }
//
//    @Test("Sync and Async - Same API (async)")
//    func syncAndAsyncSameAPIAsync() async throws {
//        try await File.Directory.temporary { dir in
//            let file = File(dir, appending: "sync-async.txt")
//            let path = file.path
//            let data: [UInt8] = Array("Test content".utf8)
//
//            // Convenience API (async)
//            try await file.write(data)
//            let readData = try await file.read()
//            #expect(readData == data)
//
//            // Primitive API (async)
//            try await File.System.Write.Atomic.write(data, to: path, options: .init(durability: .full))
//        }
//    }
//
//    // MARK: - Streaming Bytes
//
//    @Test("Streaming Bytes")
//    func streamingBytes() async throws {
//        try await File.Directory.temporary { dir in
//            let file = File(dir, appending: "stream.txt")
//            let content = String(repeating: "x", count: 10_000)
//            try await file.write(Array(content.utf8))
//
//            let path = file.path
//
//            // Async byte streaming with backpressure
//            var totalBytes = 0
//            for try await chunk in File.System.Read.bytes(from: path) {
//                totalBytes += chunk.count
//            }
//            #expect(totalBytes == content.count)
//        }
//    }
//
//    // MARK: - Usage Examples: Basic File Operations
//
//    @Test("Usage Examples - Basic File Operations")
//    func usageExamplesBasicFileOperations() throws {
//        try File.Directory.temporary { dir in
//            let file = File(dir, appending: "config.json")
//            let jsonString: [UInt8] = Array("{\"key\": \"value\"}".utf8)
//
//            // Simple read/write (uses safe defaults)
//            try file.write(jsonString)
//            let content = try file.readString() as String
//            #expect(content.contains("key"))
//
//            // Copy and move
//            let backup = File(dir, appending: "config.backup.json")
//            try file.copy(to: backup)
//
//            let newLocation = File(dir, appending: "new-location.json")
//            try file.move(to: newLocation)
//        }
//    }
//
//    // MARK: - Usage Examples: Advanced Write Options (Durability)
//
//    @Test("Usage Examples - Advanced Write Options (Durability)")
//    func usageExamplesAdvancedWriteOptions() throws {
//        try File.Directory.temporary { dir in
//            let data: [UInt8] = Array("Important data".utf8)
//
//            // Full durability
//            let path1 = File.Path(dir.path, appending: "full.txt")
//            try File.System.Write.Atomic.write(
//                data,
//                to: path1,
//                options: .init(durability: .full)
//            )
//
//            // Data-only sync
//            let path2 = File.Path(dir.path, appending: "dataonly.txt")
//            try File.System.Write.Atomic.write(
//                data,
//                to: path2,
//                options: .init(durability: .dataOnly)
//            )
//
//            // No sync (fastest, for temporary files)
//            let path3 = File.Path(dir.path, appending: "none.txt")
//            try File.System.Write.Atomic.write(
//                data,
//                to: path3,
//                options: .init(durability: .none)
//            )
//        }
//    }
//
//    // MARK: - Usage Examples: Advanced Copy Options
//
//    @Test("Usage Examples - Advanced Copy Options")
//    func usageExamplesAdvancedCopyOptions() throws {
//        try File.Directory.temporary { dir in
//            let source = File.Path(dir.path, appending: "source.txt")
//            try File.System.Write.Atomic.write(Array("source".utf8), to: source)
//
//            // Copy with attributes (permissions, timestamps)
//            let destination1 = File.Path(dir.path, appending: "dest1.txt")
//            try File.System.Copy.copy(
//                from: source,
//                to: destination1,
//                options: .init(copyAttributes: true, overwrite: true)
//            )
//
//            // Handle symlinks explicitly
//            let destination2 = File.Path(dir.path, appending: "dest2.txt")
//            try File.System.Copy.copy(
//                from: source,
//                to: destination2,
//                options: .init(followSymlinks: false)
//            )
//        }
//    }
//
//    // MARK: - Usage Examples: Directory Operations
//
//    @Test("Usage Examples - Directory Operations")
//    func usageExamplesDirectoryOperations() throws {
//        try File.Directory.temporary { baseDir in
//            let projectDir = File.Directory(baseDir, appending: "project")
//
//            // Create directory structure
//            try projectDir.create(recursive: true)
//            let srcDir = projectDir[directory: "src"]
//            try srcDir.create()
//
//            // Create some files for testing
//            let testFile = File(srcDir.path, appending: "main.swift")
//            try testFile.write(Array("// main".utf8))
//
//            // List contents
//            let files = try projectDir.files()
//            let subdirs = try projectDir.subdirectories()
//            _ = files
//            _ = subdirs
//
//            // Check if empty (won't be, we have src/)
//            if try projectDir.isEmpty {
//                try projectDir.delete()
//            }
//
//            // Copy/move directories
//            let backupDir = File.Directory(baseDir, appending: "backup")
//            try projectDir.copy(to: backupDir)
//
//            let newProjectDir = File.Directory(baseDir, appending: "new-project")
//            try backupDir.move(to: newProjectDir)
//        }
//    }
//
//    // MARK: - Usage Examples: Directory Traversal with Filtering
//
//    @Test("Usage Examples - Directory Traversal with Filtering")
//    func usageExamplesDirectoryTraversalWithFiltering() throws {
//        try File.Directory.temporary { baseDir in
//            // Create test structure
//            let rootPath = File.Path(baseDir, appending: "root")
//            try File.System.Create.Directory.create(at: rootPath, options: .init(recursive: true))
//
//            let swiftFile = File.Path(rootPath, appending: "test.swift")
//            try File.System.Write.Atomic.write(Array("// swift".utf8), to: swiftFile)
//
//            let txtFile = File.Path(rootPath, appending: "readme.txt")
//            try File.System.Write.Atomic.write(Array("readme".utf8), to: txtFile)
//
//            // Walk with options
//            let options = File.Directory.Walk.Options(
//                followSymlinks: false,
//                skipHidden: true,
//                maxDepth: 5
//            )
//
//            var swiftFileCount = 0
//            for entry in try File.Directory.Walk(at: rootPath, options: options)
//            where entry.type == .regular && entry.name.hasSuffix(".swift") {
//                swiftFileCount += 1
//                _ = entry.path
//            }
//            #expect(swiftFileCount == 1)
//        }
//    }
//
//    // MARK: - Usage Examples: Custom Executor (Advanced)
//
//    @Test("Usage Examples - Custom Executor (Advanced)")
//    func usageExamplesCustomExecutor() async throws {
//        try await File.Directory.temporary { dir in
//            let path = File.Path(dir.path, appending: "executor-test.txt")
//            try await File.System.Write.Atomic.write(Array("test".utf8), to: path)
//
//            // For heavy I/O, use a custom executor with more workers
//            let io = File.IO.Executor(.init(workers: 4))
//
//            // Pass custom executor to any operation
//            let data = try await File.System.Read.Full.read(from: path, io: io)
//            #expect(data.count > 0)
//
//            for try await entry in File.Directory.entries(at: dir, io: io) {
//                _ = entry.name
//            }
//
//            // Explicit executors must be shut down when done
//            await io.shutdown()
//        }
//    }
//
//    // MARK: - Testing Your Code
//
//    @Test("Testing Your Code - Temporary.Scope")
//    func testingYourCodeTemporaryScope() throws {
//        // This is the example from "Testing Your Code" section
//        try File.Directory.temporary { dir in
//            // dir is a File.Path to a fresh temp directory
//            let testFile = File(dir, appending: "test.txt")
//            try testFile.write("test data")
//            // directory automatically deleted when closure exits
//
//            #expect(testFile.exists)
//        }
//    }
//
//    @Test("Testing Your Code - Temporary.Scope (async)")
//    func testingYourCodeTemporaryScopeAsync() async throws {
//        try await File.Directory.temporary { dir in
//            let testFile = File(dir, appending: "test.txt")
//            try await testFile.write("test data")
//
//            #expect(testFile.exists)
//        }
//    }
//}
