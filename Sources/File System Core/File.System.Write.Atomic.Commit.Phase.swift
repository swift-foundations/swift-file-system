import Kernel

extension File.System.Write.Atomic.Commit {

    public enum Phase: UInt8, Sendable, Equatable {

        case pending = 0

        case writing = 1

        case syncedFile = 2

        case closed = 3

        case renamedPublished = 4

        case directorySyncAttempted = 5

        case syncedDirectory = 6
    }
}

extension File.System.Write.Atomic.Commit.Phase {

    public var published: Bool { self >= .renamedPublished }

    public var durabilityAttempted: Bool { self >= .directorySyncAttempted }
}

extension File.System.Write.Atomic.Commit.Phase: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
