//
//  File.IO.Blocking.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.IO {
    /// Namespace for blocking I/O lane abstractions.
    ///
    /// Contains the `Lane` protocol and default `Threads` implementation
    /// for running blocking syscalls without starving Swift's cooperative pool.
    public enum Blocking {}
}
