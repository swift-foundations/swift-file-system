//
//  File.System.Write.Streaming.Commit.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for commit-related types.
    public enum Commit {
    }
}

// MARK: - Backward Compatibility

extension File.System.Write.Streaming {
    @available(*, deprecated, renamed: "Commit.Policy")
    public typealias CommitPolicy = Commit.Policy
}
