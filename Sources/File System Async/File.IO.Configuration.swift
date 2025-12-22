//
//  File.IO.Configuration.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    public import WinSDK
#endif

extension File.IO {
    /// Configuration for the I/O executor.
    public struct Configuration: Sendable {
        /// Number of concurrent workers.
        public var workers: Int

        /// Maximum number of jobs in the queue.
        public var queueLimit: Int

        /// Default number of workers based on system resources.
        public static var defaultWorkerCount: Int {
            #if canImport(Darwin)
                return Int(sysconf(_SC_NPROCESSORS_ONLN))
            #elseif canImport(Glibc)
                return Int(sysconf(Int32(_SC_NPROCESSORS_ONLN)))
            #elseif os(Windows)
                return Int(GetActiveProcessorCount(WORD(ALL_PROCESSOR_GROUPS)))
            #else
                return 4  // Fallback for unknown platforms
            #endif
        }

        /// Creates a configuration.
        ///
        /// - Parameters:
        ///   - workers: Number of concurrent workers (default: active processor count).
        ///   - queueLimit: Maximum queue size (default: 10,000).
        public init(
            workers: Int? = nil,
            queueLimit: Int = 10_000
        ) {
            self.workers = max(1, workers ?? Self.defaultWorkerCount)
            self.queueLimit = max(1, queueLimit)
        }

        /// Default configuration for the shared executor.
        ///
        /// Conservative settings designed for the common case:
        /// - Workers: half of available cores (minimum 2)
        /// - Queue limit: 256 (bounded but reasonable)
        public static let `default` = Self(
            workers: max(2, defaultWorkerCount / 2),
            queueLimit: 256
        )
    }
}
