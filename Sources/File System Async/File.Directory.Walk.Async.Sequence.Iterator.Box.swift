//
//  File.Directory.Walk.Async.Sequence.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Walk.Async.Sequence.Iterator {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `io.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern
    final class Box: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<File.Directory.Iterator>?

        init(_ iterator: consuming File.Directory.Iterator) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume iterator)
        }

        deinit {
            // INVARIANT: Iterator.Box.deinit performs no cleanup.
            // All cleanup must occur via close() inside io.run.
            // This preserves the executor-confinement invariant.
            //
            // If storage != nil here, the handle will leak until process exit.
            // This is programmer error - the walk was not completed or terminated.
            #if DEBUG
            precondition(
                storage == nil,
                """
                Iterator.Box deallocated without close().
                This violates the io.run-only invariant.
                The walk must complete or be terminated.
                """
            )
            #endif
        }

        func next() throws -> File.Directory.Entry? {
            guard let ptr = storage else { return nil }
            return try ptr.pointee.next()
        }

        func close() {
            guard let ptr = storage else { return }
            let it = ptr.move()
            ptr.deallocate()
            storage = nil
            it.close()
        }
    }
}
