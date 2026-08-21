public import Kernel

extension File.System.Metadata {

    public struct Info: Sendable {

        public let size: Kernel.File.Size

        public let permissions: Permissions

        public let owner: Ownership

        public let accessTime: Kernel.Time

        public let modificationTime: Kernel.Time

        public let changeTime: Kernel.Time

        public let type: Kind

        public let inode: Kernel.Inode

        public let device: Kernel.Device

        public let linkCount: Kernel.Link.Count

        public init(
            size: Kernel.File.Size,
            permissions: Permissions,
            owner: Ownership,
            accessTime: Kernel.Time,
            modificationTime: Kernel.Time,
            changeTime: Kernel.Time,
            type: Kind,
            inode: Kernel.Inode,
            device: Kernel.Device,
            linkCount: Kernel.Link.Count
        ) {
            self.size = size
            self.permissions = permissions
            self.owner = owner
            self.accessTime = accessTime
            self.modificationTime = modificationTime
            self.changeTime = changeTime
            self.type = type
            self.inode = inode
            self.device = device
            self.linkCount = linkCount
        }
    }
}
