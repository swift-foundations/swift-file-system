import Kernel

extension File.Directory.Walk {

    @usableFromInline
    internal struct InodeKey: Hashable {
        let device: Kernel.Device
        let inode: Kernel.Inode
    }
}
