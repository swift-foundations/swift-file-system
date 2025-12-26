//
//  File.IO.Executor.Write.Entry.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import IO

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

    /// Simple FIFO waiter queue for serializing write operations.
    struct Waiters: Sendable {
        private var nextToken: UInt64 = 0
        private var queue: [(token: UInt64, continuation: CheckedContinuation<Void, Never>)] = []

        init() {}

        /// Generates a unique token for a waiter.
        mutating func generateToken() -> UInt64 {
            let token = nextToken
            nextToken += 1
            return token
        }

        /// Enqueues a waiter with its token and continuation.
        mutating func enqueue(token: UInt64, continuation: CheckedContinuation<Void, Never>) -> Bool {
            queue.append((token: token, continuation: continuation))
            return true
        }

        /// Cancels a waiter by token, returning its continuation if found.
        mutating func cancel(token: UInt64) -> CheckedContinuation<Void, Never>? {
            guard let index = queue.firstIndex(where: { $0.token == token }) else {
                return nil
            }
            return queue.remove(at: index).continuation
        }

        /// Resumes the next waiter in FIFO order.
        mutating func resumeNext() {
            guard !queue.isEmpty else { return }
            queue.removeFirst().continuation.resume()
        }

        /// Resumes all waiters.
        mutating func resumeAll() {
            let all = queue
            queue.removeAll()
            for entry in all {
                entry.continuation.resume()
            }
        }
    }
}
