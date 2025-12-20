//
//  File.System.Write.Streaming.Direct.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Write.Streaming {
    /// Namespace for direct streaming write types.
    public enum Direct {
    }
}

// MARK: - Backward Compatibility

extension File.System.Write.Streaming {
    @available(*, deprecated, renamed: "Direct.Options")
    public typealias DirectOptions = Direct.Options

    @available(*, deprecated, renamed: "Direct.Strategy")
    public typealias DirectStrategy = Direct.Strategy
}
