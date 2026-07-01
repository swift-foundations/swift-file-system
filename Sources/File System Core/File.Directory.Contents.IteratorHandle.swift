//
//  File.Directory.Contents.IteratorHandle.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

import Kernel

extension File.Directory.Contents {
    // WHY: Category C — thread-confined. All access happens on the iteration
    // WHY: caller's thread. The @unchecked exists to cross the init boundary.
    // WHEN TO REMOVE: After ~Sendable (SE-0518) stabilizes.
    // TRACKING: ownership-transfer-conventions.md Tier 1.
    /// Handle type for iterator cleanup.
    ///
    /// This wraps the underlying Kernel.Directory.Stream for proper resource management.
    public final class IteratorHandle: @unchecked Sendable {
        internal let stream: Kernel.Directory.Stream

        internal init(stream: Kernel.Directory.Stream) {
            self.stream = stream
        }

        deinit {
            stream.close()
        }
    }
}
