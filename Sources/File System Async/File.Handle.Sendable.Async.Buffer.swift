//
//  File.Handle.Sendable.Async.Buffer.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

/// Wrapper to pass buffer pointers across Sendable boundaries.
///
/// SAFETY: The caller MUST ensure the underlying buffer remains valid
/// for the entire duration of the async call. This wrapper exists because
/// Swift's Sendable checking is more conservative than necessary for our
/// specific use case where the buffer is used synchronously within io.run.
extension File.Handle.Sendable.Async {
    struct Buffer: @unchecked Swift.Sendable {
        let pointer: UnsafeMutableRawBufferPointer
    }
}
