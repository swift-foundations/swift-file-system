//
//  File.System.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

public import Kernel

extension File {
    /// Namespace for file system operations.
    public enum System {

    }
}

// MARK: - Error Namespace

extension File.System {
    /// Namespace for error-related types.
    public enum Error {

    }

    /// Returns whether two paths resolve to the same file-system object.
    ///
    /// The comparison follows symbolic links and uses the stable device and
    /// inode identity reported by the file system, so distinct path spellings
    /// for the same object compare equal.
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
