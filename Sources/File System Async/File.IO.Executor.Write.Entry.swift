//
//  File.IO.Executor.Write.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

// Platform-specific write context typealias.
// Both POSIXStreaming.Write.Context and WindowsStreaming.Write.Context are @unchecked Sendable.
#if os(Windows)
    typealias PlatformWriteContext = WindowsStreaming.Write.Context
#else
    typealias PlatformWriteContext = POSIXStreaming.Write.Context
#endif

extension File.IO.Executor.Write {
    /// State machine for streaming write lifecycle.
    ///
    /// States per plan section 9.2:
    /// - open: Ready to receive chunks
    /// - flushing: Syncing data to disk
    /// - committing: Performing atomic rename and directory sync
    /// - aborting: Cleaning up after abort request
    /// - closed: Terminal state
    enum State: Hashable {
        case open
        case flushing
        case committing
        case aborting
        case closed
    }

    /// Internal entry in the streaming write registry.
    ///
    /// Uses a class to hold the platform-specific write context.
    /// Actor isolation ensures thread safety without @unchecked Sendable.
    ///
    /// ## Serialization
    /// Only one operation may be in-flight at a time. The waiter queue
    /// serializes concurrent access using the same pattern as Handle.Entry.
    final class Entry {
        /// The platform-specific write context.
        /// Extracted before lane.run calls since it's Sendable.
        var context: PlatformWriteContext?

        /// Current state of this write.
        var state: State

        /// Whether an operation is currently in-flight.
        var isOperationInFlight: Bool

        /// Queue of tasks waiting to perform an operation.
        var waiters: Waiters

        /// The destination path for this write.
        let path: File.Path

        /// The options used for this write.
        let options: File.System.Write.Streaming.Options

        init(
            context: PlatformWriteContext,
            path: File.Path,
            options: File.System.Write.Streaming.Options
        ) {
            self.context = context
            self.state = .open
            self.isOperationInFlight = false
            self.waiters = Waiters()
            self.path = path
            self.options = options
        }
    }

    /// Reuse the same Waiters implementation as Handle.
    typealias Waiters = File.IO.Executor.Handle.Waiters
}
