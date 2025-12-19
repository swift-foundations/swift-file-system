//
//  File.Directory Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import Testing

@testable import File_System

extension File.Directory.Test.Unit {    
    // MARK: - Test Fixtures
    
    private func createTempDir() throws -> File.Directory {
        let pathString = "/tmp/directory-instance-test-\(uniqueId())"
        let dir = try File.Directory(pathString)
        try dir.create(withIntermediates: true)
        return dir
    }
    
    private func cleanup(_ dir: File.Directory) {
        try? dir.delete(recursive: true)
    }
    
    private func uniqueId() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<16).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Initializers
    
    @Test
    func `init from path`() throws {
        let path = try File.Path("/tmp/test")
        let dir = File.Directory(path)
        #expect(dir.path == path)
    }
    
    @Test
    func `init from string`() throws {
        let dir = try File.Directory("/tmp/test")
        #expect(dir.path.string == "/tmp/test")
    }
    
    @Test
    func `init from string literal`() {
        let dir: File.Directory = "/tmp/test"
        #expect(dir.path.string == "/tmp/test")
    }
    
    // MARK: - Directory Operations
    
    @Test
    func `create creates directory`() throws {
        let pathString = "/tmp/directory-instance-create-\(uniqueId())"
        let dir = try File.Directory(pathString)
        defer { cleanup(dir) }
        
        #expect(dir.exists == false)
        try dir.create()
        #expect(dir.exists == true)
        #expect(dir.isDirectory == true)
    }
    
    @Test
    func `create with intermediates`() throws {
        let id = uniqueId()
        let pathString = "/tmp/directory-instance-create-\(id)/nested/path"
        let dir = try File.Directory(pathString)
        let root = try File.Directory("/tmp/directory-instance-create-\(id)")
        defer { cleanup(root) }
        
        #expect(dir.exists == false)
        try dir.create(withIntermediates: true)
        #expect(dir.exists == true)
    }
    
    @Test
    func `create async creates directory`() async throws {
        let pathString = "/tmp/directory-instance-create-async-\(uniqueId())"
        let dir = try File.Directory(pathString)
        defer { cleanup(dir) }
        
        try await dir.create()
        #expect(dir.isDirectory == true)
    }
    
    @Test
    func `delete removes empty directory`() throws {
        let dir = try createTempDir()
        
        #expect(dir.exists == true)
        try dir.delete()
        #expect(dir.exists == false)
    }
    
    @Test
    func `delete recursive removes directory with contents`() throws {
        let dir = try createTempDir()
        let file = dir["test.txt"]
        try file.write("test")
        
        #expect(dir.exists == true)
        try dir.delete(recursive: true)
        #expect(dir.exists == false)
    }
    
    @Test
    func `delete async removes directory`() async throws {
        let dir = try createTempDir()
        
        #expect(dir.exists == true)
        try await dir.delete()
        #expect(dir.exists == false)
    }
    
    // MARK: - Stat Operations
    
    @Test
    func `exists returns true for existing directory`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        #expect(dir.exists == true)
    }
    
    @Test
    func `exists returns false for non-existing directory`() throws {
        let dir = try File.Directory("/tmp/non-existing-\(uniqueId())")
        #expect(dir.exists == false)
    }
    
    @Test
    func `isDirectory returns true for directory`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        #expect(dir.isDirectory == true)
    }
    
    // MARK: - Contents
    
    @Test
    func `contents returns directory entries`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        // Create some files
        try dir["file1.txt"].write("content1")
        try dir["file2.txt"].write("content2")
        
        let contents = try dir.contents()
        let names = contents.map(\.name).sorted()
        
        #expect(names == ["file1.txt", "file2.txt"])
    }
    
    @Test
    func `contents async returns directory entries`() async throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        try await dir["test.txt"].write("test")
        
        let contents = try await dir.contents()
        #expect(contents.count == 1)
        #expect(contents[0].name == "test.txt")
    }
    
    @Test
    func `files returns only files`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        // Create file and subdirectory
        try dir["file.txt"].write("content")
        try dir.subdirectory("subdir").create()
        
        let files = try dir.files()
        #expect(files.count == 1)
        #expect(files[0].name == "file.txt")
    }
    
    @Test
    func `subdirectories returns only directories`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        // Create file and subdirectory
        try dir["file.txt"].write("content")
        try dir.subdirectory("subdir").create()
        
        let subdirs = try dir.subdirectories()
        #expect(subdirs.count == 1)
        #expect(subdirs[0].name == "subdir")
    }
    
    // MARK: - Subscript Access
    
    @Test
    func `subscript returns File`() {
        let dir: File.Directory = "/tmp/mydir"
        let file = dir["readme.txt"]
        
        #expect(file.path.string == "/tmp/mydir/readme.txt")
    }
    
    @Test
    func `subscript chain works`() throws {
        let dir = try createTempDir()
        defer { cleanup(dir) }
        
        let file = dir["test.txt"]
        try file.write("Hello")
        
        let readBack = try dir["test.txt"].readString()
        #expect(readBack == "Hello")
    }
    
    @Test
    func `subdirectory returns Directory.Instance`() {
        let dir: File.Directory = "/tmp/mydir"
        let subdir = dir.subdirectory("nested")
        
        #expect(subdir.path.string == "/tmp/mydir/nested")
    }
    
    // MARK: - Path Navigation
    
    @Test
    func `parent returns parent directory`() {
        let dir: File.Directory = "/tmp/parent/child"
        let parent = dir.parent
        
        #expect(parent != nil)
        #expect(parent?.path.string == "/tmp/parent")
    }
    
    @Test
    func `name returns directory name`() {
        let dir: File.Directory = "/tmp/mydir"
        #expect(dir.name == "mydir")
    }
    
    @Test
    func `appending returns new instance`() {
        let dir: File.Directory = "/tmp"
        let result = dir.appending("subdir")
        #expect(result.path.string == "/tmp/subdir")
    }
    
    @Test
    func `/ operator appends path`() {
        let dir: File.Directory = "/tmp"
        let result = dir / "subdir" / "nested"
        #expect(result.path.string == "/tmp/subdir/nested")
    }
    
    // MARK: - Hashable & Equatable
    
    @Test
    func `File.Directory is equatable`() {
        let dir1: File.Directory = "/tmp/test"
        let dir2: File.Directory = "/tmp/test"
        let dir3: File.Directory = "/tmp/other"
        
        #expect(dir1 == dir2)
        #expect(dir1 != dir3)
    }
    
    @Test
    func `File.Directory is hashable`() {
        let dir1: File.Directory = "/tmp/test"
        let dir2: File.Directory = "/tmp/test"
        
        var set = Set<File.Directory>()
        set.insert(dir1)
        set.insert(dir2)
        
        #expect(set.count == 1)
    }
    
    // MARK: - CustomStringConvertible
    
    @Test
    func `description returns path string`() {
        let dir: File.Directory = "/tmp/test"
        #expect(dir.description == "/tmp/test")
    }
    
    @Test
    func `debugDescription returns formatted string`() {
        let dir: File.Directory = "/tmp/test"
        #expect(dir.debugDescription == #"File.Directory("/tmp/test")"#)
    }
    
}
