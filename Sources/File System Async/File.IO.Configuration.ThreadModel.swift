//
//  File.IO.Configuration.ThreadModel.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.IO.Configuration {
    /// Thread model for executing I/O operations.
    public enum ThreadModel: Sendable {
        /// Cooperative thread pool using `Task.detached`.
        ///
        /// Uses Swift's default cooperative thread pool. Under sustained blocking I/O,
        /// this can starve unrelated async work.
        case cooperative

        /// Dedicated thread pool using `DispatchQueue`.
        ///
        /// Creates explicit dispatch queues with user-initiated QoS.
        /// Prevents blocking I/O from starving the cooperative pool.
        case dedicated
    }
}
