import Binary_Primitives

extension File.Directory.Entry {

    public enum Kind: Sendable {

        case file

        case directory

        case symbolicLink

        case other
    }
}

extension File.Directory.Entry.Kind: RawRepresentable {
    public var rawValue: Byte {
        switch self {
        case .file: return 0
        case .directory: return 1
        case .symbolicLink: return 2
        case .other: return 3
        }
    }

    public init?(rawValue: Byte) {
        switch rawValue {
        case 0: self = .file
        case 1: self = .directory
        case 2: self = .symbolicLink
        case 3: self = .other
        default: return nil
        }
    }
}

extension File.Directory.Entry.Kind: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(value.rawValue)
    }
}
