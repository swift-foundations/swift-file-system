//
//  File.Directory.Async.Walk.Sequence.Iterator.Box.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

extension File.Directory.Async.WalkSequence {
    /// Heap-allocated box for the non-copyable iterator.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// - Only accessed from within `io.run` closures (single-threaded access)
    /// - Never accessed concurrently
    /// - Caller ensures sequential access pattern
    final class IteratorBox: @unchecked Sendable {
        private var storage: UnsafeMutablePointer<File.Directory.Iterator>?

        init(_ iterator: consuming File.Directory.Iterator) {
            self.storage = .allocate(capacity: 1)
            self.storage!.initialize(to: consume iterator)
        }

        deinit {
            if let ptr = storage {
                let it = ptr.move()
                ptr.deallocate()
                it.close()
            }
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
