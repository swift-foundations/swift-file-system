import Kernel

extension File.System.Write.Atomic {

    public struct Preservation: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

extension File.System.Write.Atomic.Preservation {

    public static let permissions = Self(rawValue: 1 << 0)

    public static let timestamps = Self(rawValue: 1 << 1)

    public static let extendedAttributes = Self(rawValue: 1 << 2)

    public static let acls = Self(rawValue: 1 << 3)

    public static let all: Self = [
        .permissions, .timestamps, .extendedAttributes, .acls,
    ]
}
