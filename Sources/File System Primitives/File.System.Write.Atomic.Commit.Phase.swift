//
//  File.System.Write.Atomic.Commit.Phase.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic.Commit {
    /// Tracks progress through the atomic write operation.
    ///
    /// Use `published` to determine if the file exists at its destination after failure.
    /// Use `durabilityAttempted` for postmortem diagnostics.
    ///
    /// ## Usage
    /// After catching an error, check the phase to understand the file state:
    /// ```swift
    /// do {
    ///     try atomicWrite(data, to: path)
    /// } catch {
    ///     if phase.published {
    ///         // File exists at destination, but durability may be compromised
    ///     } else {
    ///         // File was NOT written to destination
    ///     }
    /// }
    /// ```
    public enum Phase: UInt8, Sendable, Equatable {
        /// Operation not yet started.
        case pending = 0

        /// Writing data to temp file.
        case writing = 1

        /// File data synced to disk.
        case syncedFile = 2

        /// Temp file closed.
        case closed = 3

        /// File atomically renamed to destination (published).
        case renamedPublished = 4

        /// Directory sync was started but not confirmed complete.
        case directorySyncAttempted = 5

        /// Directory synced, fully durable.
        case syncedDirectory = 6
    }
}

// MARK: - Properties

extension File.System.Write.Atomic.Commit.Phase {
    /// Returns true if file has been atomically published to destination.
    ///
    /// When this is true, the file exists with complete contents at the destination path.
    /// However, durability may not be guaranteed if `durabilityAttempted` is false.
    public var published: Bool { self.rawValue >= Self.renamedPublished.rawValue }

    /// Returns true if directory sync was attempted (for postmortem diagnostics).
    ///
    /// Distinguishes "sync started but failed/cancelled" from "sync never attempted".
    public var durabilityAttempted: Bool { self.rawValue >= Self.directorySyncAttempted.rawValue }
}

// MARK: - Comparable

extension File.System.Write.Atomic.Commit.Phase: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
