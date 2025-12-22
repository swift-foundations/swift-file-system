//
//  File.System.Metadata.Timestamps Tests.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

@_spi(Internal) import StandardTime
import StandardsTestSupport
import Testing

@testable import File_System_Primitives

#if canImport(Foundation)
    import Foundation
#endif

extension File.System.Metadata.Timestamps {
    #TestSuites
}

extension File.System.Metadata.Timestamps.Test.Unit {

    // MARK: - Test Fixtures

    private func createTempFile() throws -> String {
        #if canImport(Foundation)
            let path = "/tmp/timestamps-test-\(Int.random(in: 0..<Int.max)).txt"
            FileManager.default.createFile(atPath: path, contents: nil)
            return path
        #else
            let path = "/tmp/timestamps-test-\(Int.random(in: 0..<Int.max)).txt"
            let filePath = try File.Path(path)
            try File.System.Write.Atomic.write([].span, to: filePath)
            return path
        #endif
    }

    private func cleanup(_ path: String) {
        if let filePath = try? File.Path(path) {
            try? File.System.Delete.delete(at: filePath)
        }
    }

    // MARK: - Initialization

    @Test("Timestamps initialization")
    func timestampsInitialization() {
        let now = Time(__unchecked: (), secondsSinceEpoch: 1_702_900_000, nanoseconds: 0)
        let timestamps = File.System.Metadata.Timestamps(
            accessTime: now,
            modificationTime: now,
            changeTime: now,
            creationTime: now
        )

        #expect(timestamps.accessTime == now)
        #expect(timestamps.modificationTime == now)
        #expect(timestamps.changeTime == now)
        #expect(timestamps.creationTime == now)
    }

    @Test("Timestamps initialization without creationTime")
    func timestampsInitializationWithoutCreationTime() {
        let now = Time(__unchecked: (), secondsSinceEpoch: 1_702_900_000, nanoseconds: 0)
        let timestamps = File.System.Metadata.Timestamps(
            accessTime: now,
            modificationTime: now,
            changeTime: now
        )

        #expect(timestamps.creationTime == nil)
    }

    // MARK: - Get Timestamps

    @Test("Get timestamps of file")
    func getTimestampsOfFile() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)
        let timestamps = try File.System.Metadata.Timestamps(at: filePath)

        // Timestamps should be positive (i.e., after Unix epoch)
        #expect(timestamps.accessTime.secondsSinceEpoch > 0)
        #expect(timestamps.modificationTime.secondsSinceEpoch > 0)
    }

    @Test("Modification time updates on file write")
    func modificationTimeUpdatesOnWrite() throws {
        #if canImport(Foundation)
            let path = try createTempFile()
            defer { cleanup(path) }

            let filePath = try File.Path(path)
            let beforeWrite = try File.System.Metadata.Timestamps(at: filePath)

            // Wait a small amount and write to the file
            Thread.sleep(forTimeInterval: 0.1)
            try Data([1, 2, 3]).write(to: URL(fileURLWithPath: path))

            let afterWrite = try File.System.Metadata.Timestamps(at: filePath)

            #expect(
                afterWrite.modificationTime.secondsSinceEpoch
                    >= beforeWrite.modificationTime.secondsSinceEpoch
            )
        #else
            // Skip test on non-Foundation platforms - requires Data and URL
        #endif
    }

    // MARK: - Set Timestamps

    @Test("Set timestamps of file")
    func setTimestampsOfFile() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)

        // Set to a specific time (Jan 1, 2020 00:00:00 UTC)
        let targetTime = Time(__unchecked: (), secondsSinceEpoch: 1_577_836_800, nanoseconds: 0)
        let timestamps = File.System.Metadata.Timestamps(
            accessTime: targetTime,
            modificationTime: targetTime,
            changeTime: targetTime
        )

        try File.System.Metadata.Timestamps.set(timestamps, at: filePath)

        let readBack = try File.System.Metadata.Timestamps(at: filePath)
        #expect(readBack.accessTime.secondsSinceEpoch == targetTime.secondsSinceEpoch)
        #expect(readBack.modificationTime.secondsSinceEpoch == targetTime.secondsSinceEpoch)
    }

    @Test("Set different access and modification times")
    func setDifferentTimes() throws {
        let path = try createTempFile()
        defer { cleanup(path) }

        let filePath = try File.Path(path)

        let accessTime = Time(__unchecked: (), secondsSinceEpoch: 1_577_836_800, nanoseconds: 0)  // Jan 1, 2020
        let modTime = Time(__unchecked: (), secondsSinceEpoch: 1_609_459_200, nanoseconds: 0)  // Jan 1, 2021

        let timestamps = File.System.Metadata.Timestamps(
            accessTime: accessTime,
            modificationTime: modTime,
            changeTime: modTime
        )

        try File.System.Metadata.Timestamps.set(timestamps, at: filePath)

        let readBack = try File.System.Metadata.Timestamps(at: filePath)
        #expect(readBack.accessTime.secondsSinceEpoch == accessTime.secondsSinceEpoch)
        #expect(readBack.modificationTime.secondsSinceEpoch == modTime.secondsSinceEpoch)
    }

    // MARK: - Error Cases

    @Test("Get timestamps of non-existent file throws pathNotFound")
    func getTimestampsOfNonExistentFileThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)

        #expect(throws: File.System.Metadata.Timestamps.Error.pathNotFound(path)) {
            _ = try File.System.Metadata.Timestamps(at: path)
        }
    }

    @Test("Set timestamps of non-existent file throws pathNotFound")
    func setTimestampsOfNonExistentFileThrows() throws {
        let nonExistent = "/tmp/non-existent-\(Int.random(in: 0..<Int.max))"
        let path = try File.Path(nonExistent)

        let testTime = Time(__unchecked: (), secondsSinceEpoch: 1_702_900_000, nanoseconds: 0)
        let timestamps = File.System.Metadata.Timestamps(
            accessTime: testTime,
            modificationTime: testTime,
            changeTime: testTime
        )

        #expect(throws: File.System.Metadata.Timestamps.Error.pathNotFound(path)) {
            try File.System.Metadata.Timestamps.set(timestamps, at: path)
        }
    }

    // MARK: - Error Descriptions

    @Test("pathNotFound error description")
    func pathNotFoundErrorDescription() {
        let path: File.Path = "/tmp/missing"
        let error = File.System.Metadata.Timestamps.Error.pathNotFound(path)
        #expect(error.description.contains("Path not found"))
    }

    @Test("permissionDenied error description")
    func permissionDeniedErrorDescription() {
        let path: File.Path = "/root/secret"
        let error = File.System.Metadata.Timestamps.Error.permissionDenied(path)
        #expect(error.description.contains("Permission denied"))
    }

    @Test("operationFailed error description")
    func operationFailedErrorDescription() {
        let error = File.System.Metadata.Timestamps.Error.operationFailed(
            errno: 22,
            message: "Invalid argument"
        )
        #expect(error.description.contains("Operation failed"))
    }

    // MARK: - Equatable

    @Test("Timestamps are equatable")
    func timestampsAreEquatable() {
        let time1 = Time(__unchecked: (), secondsSinceEpoch: 1000, nanoseconds: 0)
        let time2 = Time(__unchecked: (), secondsSinceEpoch: 2000, nanoseconds: 0)

        let ts1 = File.System.Metadata.Timestamps(
            accessTime: time1,
            modificationTime: time1,
            changeTime: time1
        )

        let ts2 = File.System.Metadata.Timestamps(
            accessTime: time1,
            modificationTime: time1,
            changeTime: time1
        )

        let ts3 = File.System.Metadata.Timestamps(
            accessTime: time2,
            modificationTime: time1,
            changeTime: time1
        )

        #expect(ts1 == ts2)
        #expect(ts1 != ts3)
    }
}
