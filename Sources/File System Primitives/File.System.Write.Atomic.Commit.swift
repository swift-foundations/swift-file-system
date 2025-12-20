//
//  File.System.Write.Atomic.Commit.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Atomic {
    /// Namespace for commit-related types.
    public enum Commit {
    }
}

// MARK: - Backward Compatibility

extension File.System.Write.Atomic {
    @available(*, deprecated, renamed: "Commit.Phase")
    public typealias CommitPhase = Commit.Phase
}
