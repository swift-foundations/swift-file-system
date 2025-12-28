//
//  File.Write.Streaming.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 27/12/2025.
//

// Platform-specific write context typealias.
// Both POSIX.Context and Windows.Context are @unchecked Sendable.
#if os(Windows)
    typealias PlatformWriteContext = File.System.Write.Streaming.Windows.Context
#else
    typealias PlatformWriteContext = File.System.Write.Streaming.POSIX.Context
#endif

extension File {
    /// Namespace for write operations.
    public enum Write {}
}

extension File.Write {
    /// A streaming write resource managed by IO.Executor.Pool.
    ///
    /// Serialization, cancellation, and backpressure are handled by the Pool.
    /// This type only holds the platform-specific context and state.
    public struct Streaming: ~Copyable {
        /// The platform-specific write context.
        var context: PlatformWriteContext

        /// Current state of this write.
        var state: State

        /// The destination path for this write.
        let path: File.Path

        /// The options used for this write.
        let options: File.System.Write.Streaming.Options

        /// Creates a new streaming write resource.
        init(
            context: PlatformWriteContext,
            path: File.Path,
            options: File.System.Write.Streaming.Options
        ) {
            self.context = context
            self.state = .open
            self.path = path
            self.options = options
        }
    }
}

extension File.Write.Streaming {
    /// State machine for streaming write lifecycle.
    ///
    /// States:
    /// - open: Ready to receive chunks
    /// - flushing: Syncing data to disk
    /// - committing: Performing atomic rename and directory sync
    /// - aborting: Cleaning up after abort request
    /// - closed: Terminal state
    enum State: Hashable, Sendable {
        case open
        case flushing
        case committing
        case aborting
        case closed
    }
}

// MARK: - Backwards Compatibility

extension File {
    /// Backwards compatibility alias.
    @available(*, deprecated, renamed: "File.Write.Streaming")
    public typealias StreamingWrite = File.Write.Streaming
}
