//
//  File.Directory.Entries.Async.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Directory.Entries.Async.Iterator {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// Uses UnsafeMutablePointer for stable address with ~Copyable type,
    /// similar to Handle.Box pattern.
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
            // If storage != nil here, it means:
            // 1. The iterator was not exhausted, AND
            // 2. terminate() was not called, AND
            // 3. The best-effort Task.detached cleanup didn't run
            //
            // This is programmer error. The handle will leak until process exit.
            // Use terminate() for deterministic cleanup.
            #if DEBUG
            precondition(
                storage == nil,
                """
                Iterator.Box deallocated without close().
                This violates the io.run-only invariant.
                The iterator must be exhausted or terminate() must be called.
                """
            )
            #endif
        }

        func next() throws -> File.Directory.Entry? {
            guard let ptr = storage else {
                return nil
            }
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
