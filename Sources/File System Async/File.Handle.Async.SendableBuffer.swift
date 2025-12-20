//
//  File.Handle.Async.SendableBuffer.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 18/12/2025.
//

/// Wrapper to pass buffer pointers across Sendable boundaries.
///
/// SAFETY: The caller MUST ensure the underlying buffer remains valid
/// for the entire duration of the async call. This wrapper exists because
/// Swift's Sendable checking is more conservative than necessary for our
/// specific use case where the buffer is used synchronously within io.run.
struct _SendableBuffer: @unchecked Sendable {
    let pointer: UnsafeMutableRawBufferPointer
}
