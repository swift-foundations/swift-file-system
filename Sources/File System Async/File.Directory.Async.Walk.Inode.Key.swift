//
//  File.Directory.Async.Walk.Inode.Key.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Unique identifier for a file (device + inode).
extension File.Directory.Async.Walk.Inode {
    struct Key: Hashable, Sendable {
        let device: UInt64
        let inode: UInt64
    }
}
