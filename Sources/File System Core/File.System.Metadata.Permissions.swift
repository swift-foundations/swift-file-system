import Binary
public import Kernel

extension File.System.Metadata {

    public struct Permissions: OptionSet, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

extension File.System.Metadata.Permissions {

    public static let ownerRead = Self(rawValue: 0o400)
    public static let ownerWrite = Self(rawValue: 0o200)
    public static let ownerExecute = Self(rawValue: 0o100)

    public static let groupRead = Self(rawValue: 0o040)
    public static let groupWrite = Self(rawValue: 0o020)
    public static let groupExecute = Self(rawValue: 0o010)

    public static let otherRead = Self(rawValue: 0o004)
    public static let otherWrite = Self(rawValue: 0o002)
    public static let otherExecute = Self(rawValue: 0o001)

    public static let setuid = Self(rawValue: 0o4000)
    public static let setgid = Self(rawValue: 0o2000)
    public static let sticky = Self(rawValue: 0o1000)

    public static let ownerAll: Self = [.ownerRead, .ownerWrite, .ownerExecute]
    public static let groupAll: Self = [.groupRead, .groupWrite, .groupExecute]
    public static let otherAll: Self = [.otherRead, .otherWrite, .otherExecute]

    public static let defaultFile: Self = [
        .ownerRead, .ownerWrite, .groupRead, .otherRead,
    ]

    public static let defaultDirectory: Self = [
        .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
    ]

    public static let executable: Self = [
        .ownerAll, .groupRead, .groupExecute, .otherRead, .otherExecute,
    ]
}

extension File.System.Metadata.Permissions {

    public enum Error: Swift.Error, Sendable {

        case stat(Kernel.File.Stats.Error)

        case chmod(Kernel.File.Attributes.Error)
    }
}

extension File.System.Metadata.Permissions.Error {

    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .chmod(let e):
            if case .path(.notFound) = e { return true }
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .chmod(let e):
            if case .permission(.denied) = e { return true }
            if case .permission(.notPermitted) = e { return true }
            return false
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .chmod(let e):
            if case .permission(.readOnlyFilesystem) = e { return true }
            return false

        default:
            return false
        }
    }
}

extension File.System.Metadata.Permissions {

    public init(at path: borrowing File.Path) throws(Self.Error) {

        do throws(Kernel.File.Stats.Error) {
            let stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
            self.init(rawValue: stats.permissions.rawValue)
        } catch {
            throw .stat(error)
        }
    }
}

extension File.System.Metadata.Permissions {

    public static func set(
        _ permissions: Self,
        at path: borrowing File.Path
    ) throws(Self.Error) {
        #if os(Windows)

            return
        #else
            do throws(Kernel.File.Attributes.Error) {
                try path.withKernelPath { kernelPath throws(Kernel.File.Attributes.Error) in
                    try Kernel.File.Attributes.set(
                        Kernel.File.Permissions(rawValue: permissions.rawValue),
                        at: kernelPath
                    )
                }
            } catch {
                throw .chmod(error)
            }
        #endif
    }
}

extension File.System.Metadata.Permissions.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"

        case .chmod(let error):
            return "Chmod failed: \(error)"
        }
    }
}

extension File.System.Metadata.Permissions: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.rawValue.bytes())
    }
}
