//
//  File.Directory.Walk.Undecodable.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 20/12/2025.
//

extension File.Directory.Walk {
    /// Namespace for handling entries with undecodable names during directory walk.
    ///
    /// When traversing directories, some filenames may contain byte sequences
    /// that cannot be decoded to valid UTF-8 (POSIX) or UTF-16 (Windows).
    /// This namespace provides types to handle such entries.
    public enum Undecodable {}
}
