//
//  File.Unsafe.Sendable.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

extension File.Unsafe {
    /// A wrapper to make non-Sendable types sendable when we know it's safe.
    ///
    /// ## Safety Invariant (for @unchecked Sendable)
    /// The wrapped value must only be accessed from a single isolation context,
    /// or the type must be effectively immutable for the duration of concurrent access.
    ///
    /// ### Usage Contract:
    /// - Caller is responsible for ensuring thread-safety
    /// - Typically used for file descriptors (Int32) which are value types
    /// - Do not use for mutable reference types without external synchronization
    @usableFromInline
    internal struct Sendable<T>: @unchecked Swift.Sendable {
        @usableFromInline
        var value: T

        @usableFromInline
        init(_ value: T) {
            self.value = value
        }
    }
}
