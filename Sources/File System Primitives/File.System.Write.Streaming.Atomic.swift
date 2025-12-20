//
//  File.System.Write.Streaming.Atomic.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for atomic streaming write types.
    public enum Atomic {
    }
}

// MARK: - Backward Compatibility

extension File.System.Write.Streaming {
    @available(*, deprecated, renamed: "Atomic.Options")
    public typealias AtomicOptions = Atomic.Options

    @available(*, deprecated, renamed: "Atomic.Strategy")
    public typealias AtomicStrategy = Atomic.Strategy
}
