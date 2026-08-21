public import Kernel

extension File.System {

    public enum Stat {}
}

extension File.System.Stat {

    @inlinable
    public static func info(
        at path: borrowing File.Path,
        followSymlinks: Bool = true
    ) throws(Kernel.File.Stats.Error) -> File.System.Metadata.Info {
        let stats = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
            followSymlinks
                ? try Kernel.File.Stats.get(path: kernelPath)
                : try Kernel.File.Stats.lget(path: kernelPath)
        }
        return makeInfo(from: stats)
    }

    @inlinable
    public static func exists(at path: borrowing File.Path) -> Bool {
        do throws(Kernel.File.Stats.Error) {
            _ = try path.withKernelPath { kernelPath throws(Kernel.File.Stats.Error) in
                try Kernel.File.Stats.get(path: kernelPath)
            }
            return true
        } catch {
            return false
        }
    }
}

extension File.System.Stat {

    @usableFromInline
    internal static func makeInfo(from stats: Kernel.File.Stats) -> File.System.Metadata.Info {
        let fileType: File.System.Metadata.Kind
        switch stats.type {
        case .regular:
            fileType = .regular

        case .directory:
            fileType = .directory

        case .link:
            fileType = .symbolicLink

        case .device(.block):
            fileType = .blockDevice

        case .device(.character):
            fileType = .characterDevice

        case .fifo:
            fileType = .fifo

        case .socket:
            fileType = .socket

        case .unknown:
            fileType = .regular
        }

        return File.System.Metadata.Info(
            size: stats.size,
            permissions: File.System.Metadata.Permissions(rawValue: stats.permissions.rawValue),
            owner: File.System.Metadata.Ownership(uid: stats.uid, gid: stats.gid),
            accessTime: stats.accessTime,
            modificationTime: stats.modificationTime,
            changeTime: stats.changeTime,
            type: fileType,
            inode: stats.inode,
            device: stats.device,
            linkCount: stats.linkCount
        )
    }
}
