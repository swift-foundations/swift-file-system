//
//  File.Directory.Contents.Control.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory.Contents {
    /// Control flow for directory iteration.
    public enum Control {
        /// Continue iterating.
        case `continue`
        /// Stop iterating.
        case `break`
    }
}
