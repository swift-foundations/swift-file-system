import Binary
public import Kernel

extension File.System.Metadata {

    public struct Ownership: Sendable, Equatable {

        public var uid: Kernel.User.ID

        public var gid: Kernel.Group.ID

        public init(uid: Kernel.User.ID, gid: Kernel.Group.ID) {
            self.uid = uid
            self.gid = gid
        }
    }
}

extension File.System.Metadata.Ownership {

    public enum Error: Swift.Error, Sendable {

        case stat(Kernel.File.Stats.Error)

        case chown(Kernel.File.Chown.Error)
    }
}

extension File.System.Metadata.Ownership.Error {

    public var isNotFound: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isNotFound { return true }
            return false

        case .chown(let e):
            if case .path(.notFound) = e { return true }
            return false
        }
    }

    public var isPermissionDenied: Bool {
        switch self {
        case .stat(let e):
            if case .platform(let p) = e, p.code.isPermissionDenied { return true }
            return false

        case .chown(let e):
            if case .permission(.denied) = e { return true }
            if case .permission(.notPermitted) = e { return true }
            return false
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .chown(let e):
            if case .permission(.readOnlyFilesystem) = e { return true }
            return false

        default:
            return false
        }
    }
}

extension File.System.Metadata.Ownership {

    public init(at path: borrowing File.Path) throws(Self.Error) {
        #if os(Windows)

            do throws(Kernel.File.Stats.Error) {
                _ = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                    try Kernel.File.Stats.get(path: kernelPath)
                }
            } catch {
                throw .stat(error)
            }
            self.init(uid: 0, gid: 0)
        #else
            do throws(Kernel.File.Stats.Error) {
                let stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                    try Kernel.File.Stats.get(path: kernelPath)
                }
                self.init(uid: stats.uid, gid: stats.gid)
            } catch {
                throw .stat(error)
            }
        #endif
    }
}

extension File.System.Metadata.Ownership {

    public static func set(
        _ ownership: Self,
        at path: borrowing File.Path
    ) throws(Self.Error) {

        do throws(Kernel.File.Chown.Error) {
            try path.withKernelPath { kernelPath throws(Kernel.File.Chown.Error) in
                try Kernel.File.Chown.chown(
                    path: kernelPath,
                    uid: ownership.uid,
                    gid: ownership.gid
                )
            }
        } catch {
            throw .chown(error)
        }
    }
}

extension File.System.Metadata.Ownership.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .stat(let error):
            return "Stat failed: \(error)"

        case .chown(let error):
            return "Chown failed: \(error)"
        }
    }
}

extension File.System.Metadata.Ownership: Binary.Serializable {
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.uid.underlying.bytes())
        buffer.append(contentsOf: value.gid.underlying.bytes())
    }
}
