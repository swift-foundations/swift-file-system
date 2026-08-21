public import Kernel

extension File {

    public enum System {

    }
}

extension File.System {

    public enum Error {

    }

    @inlinable
    public static func same(
        _ first: File.Path,
        _ second: File.Path
    ) throws(Kernel.File.Stats.Error) -> Bool {
        let first = try File.System.Stat.info(at: first)
        let second = try File.System.Stat.info(at: second)
        return first.device == second.device && first.inode == second.inode
    }
}
