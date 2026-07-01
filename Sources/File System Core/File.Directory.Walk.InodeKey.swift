//
//  File.Directory.Walk.InodeKey.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

import Kernel

extension File.Directory.Walk {
    /// Key for tracking visited directories to detect cycles.
    ///
    /// Uses (device, inode) pair which uniquely identifies a file/directory
    /// across the filesystem.
    @usableFromInline
    internal struct InodeKey: Hashable {
        let device: Kernel.Device
        let inode: Kernel.Inode
    }
}
