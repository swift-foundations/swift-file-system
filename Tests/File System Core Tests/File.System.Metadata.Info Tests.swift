//
//  File.System.Metadata.Info Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

import File_System_Test_Support
import Tagged_Primitives_Standard_Library_Integration
import Testing

@testable import File_System_Core

extension File.System.Metadata.Info {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension File.System.Metadata.Info.Test.Unit {

    // MARK: - Initialization

    @Test
    func `Info initialization`() throws {
        let now = try Kernel.Time(secondsSinceUnixEpoch: 1_702_900_000, nanosecondFraction: 0)
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)
        let permissions: File.System.Metadata.Permissions = .defaultFile

        let info = File.System.Metadata.Info(
            size: 1024,
            permissions: permissions,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 12345,
            device: 1,
            linkCount: 1
        )

        #expect(info.size == 1024)
        #expect(info.permissions == permissions)
        #expect(info.owner.uid == 501)
        #expect(info.owner.gid == 20)
        #expect(info.type == .regular)
        #expect(info.inode == 12345)
        #expect(info.device == 1)
        #expect(info.linkCount == 1)
    }

    // MARK: - FileType

    @Test
    func `FileType regular case`() {
        let type: File.System.Metadata.Kind = .regular
        #expect(type == .regular)
    }

    @Test
    func `FileType directory case`() {
        let type: File.System.Metadata.Kind = .directory
        #expect(type == .directory)
    }

    @Test
    func `FileType symbolicLink case`() {
        let type: File.System.Metadata.Kind = .symbolicLink
        #expect(type == .symbolicLink)
    }

    @Test
    func `FileType blockDevice case`() {
        let type: File.System.Metadata.Kind = .blockDevice
        #expect(type == .blockDevice)
    }

    @Test
    func `FileType characterDevice case`() {
        let type: File.System.Metadata.Kind = .characterDevice
        #expect(type == .characterDevice)
    }

    @Test
    func `FileType fifo case`() {
        let type: File.System.Metadata.Kind = .fifo
        #expect(type == .fifo)
    }

    @Test
    func `FileType socket case`() {
        let type: File.System.Metadata.Kind = .socket
        #expect(type == .socket)
    }

    @Test
    func `FileType cases are distinct`() {
        #expect(File.System.Metadata.Kind.regular != .directory)
        #expect(File.System.Metadata.Kind.directory != .symbolicLink)
        #expect(File.System.Metadata.Kind.symbolicLink != .blockDevice)
        #expect(File.System.Metadata.Kind.blockDevice != .characterDevice)
        #expect(File.System.Metadata.Kind.characterDevice != .fifo)
        #expect(File.System.Metadata.Kind.fifo != .socket)
    }

    // MARK: - Info Properties

    @Test
    func `Info size property`() throws {
        let now = try Kernel.Time(secondsSinceUnixEpoch: 1_702_900_000, nanosecondFraction: 0)
        let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

        let smallFile = File.System.Metadata.Info(
            size: 100,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 1,
            device: 1,
            linkCount: 1
        )

        let largeFile = File.System.Metadata.Info(
            size: 1_000_000_000,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 2,
            device: 1,
            linkCount: 1
        )

        #expect(smallFile.size == 100)
        #expect(largeFile.size == 1_000_000_000)
    }

    @Test
    func `Info linkCount for hard links`() throws {
        let now = try Kernel.Time(secondsSinceUnixEpoch: 1_702_900_000, nanosecondFraction: 0)
        let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

        let singleLink = File.System.Metadata.Info(
            size: 100,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 1,
            device: 1,
            linkCount: 1
        )

        let multipleLinks = File.System.Metadata.Info(
            size: 100,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 1,
            device: 1,
            linkCount: 5
        )

        #expect(singleLink.linkCount == 1)
        #expect(multipleLinks.linkCount == 5)
    }

    @Test
    func `Info inode uniqueness`() throws {
        let now = try Kernel.Time(secondsSinceUnixEpoch: 1_702_900_000, nanosecondFraction: 0)
        let ownership = File.System.Metadata.Ownership(uid: 0, gid: 0)

        let file1 = File.System.Metadata.Info(
            size: 100,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 12345,
            device: 1,
            linkCount: 1
        )

        let file2 = File.System.Metadata.Info(
            size: 100,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 67890,
            device: 1,
            linkCount: 1
        )

        #expect(file1.inode != file2.inode)
    }

    // MARK: - Sendable

    @Test
    func `Info is sendable`() async throws {
        let now = try Kernel.Time(secondsSinceUnixEpoch: 1_702_900_000, nanosecondFraction: 0)
        let ownership = File.System.Metadata.Ownership(uid: 501, gid: 20)

        let info = File.System.Metadata.Info(
            size: 1024,
            permissions: .defaultFile,
            owner: ownership,
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            type: .regular,
            inode: 12345,
            device: 1,
            linkCount: 1
        )

        await Task {
            #expect(info.size == 1024)
            #expect(info.type == .regular)
        }.value
    }

    @Test
    func `FileType is sendable`() async {
        let type: File.System.Metadata.Kind = .directory

        await Task {
            #expect(type == .directory)
        }.value
    }
}
