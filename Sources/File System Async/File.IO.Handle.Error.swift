//
//  File.IO.Handle.Error.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Handle {
    /// Errors related to handle operations in the store.
    public enum Error: Swift.Error, Sendable {
        /// The handle ID does not exist in the store (already closed or never existed).
        case invalidID
        /// The handle ID belongs to a different executor/store.
        case scopeMismatch
        /// The handle has already been closed.
        case handleClosed
    }
}
