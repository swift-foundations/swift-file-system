//
//  File.IO.Executor.Unsafe.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 21/12/2025.
//

// MARK: - Handle Slot
//
// This file contains internal bridging for ~Copyable File.Handle
// across await boundaries via lane.run.
//
// ## Key Design: Integer Address Capture
// UnsafeMutableRawPointer is not Sendable in Swift 6, but UInt is.
// We expose `slot.address` as UInt and reconstruct the pointer inside
// the @Sendable lane closure. Memory lifetime is guaranteed by the
// actor-scoped Slot plus the awaited lane.run duration.
//
// ## Safety Invariants
// 1. The slot is initialized exactly once (via static `initializeMemory`)
// 2. After successful lane.run, caller marks initialized and calls `take()`
// 3. `deallocateRawOnly()` is idempotent and called via defer
//
// ## Usage Pattern
// ```swift
// var slot = Slot.allocate()
// defer { slot.deallocateRawOnly() }
// let address = slot.address
//
// try await lane.run(deadline: nil) {
//     let raw = UnsafeMutableRawPointer(bitPattern: address)!
//     let handle = try File.Handle.open(...)
//     Slot.initializeMemory(at: raw, with: handle)
// }
//
// slot.markInitialized()
// let handle = slot.take()
// // register handle
// ```

extension File.IO.Executor {
    /// A raw memory slot for temporarily holding a ~Copyable File.Handle
    /// during lane execution.
    ///
    /// This enables passing handles through @Sendable closures without
    /// claiming the handle itself is Sendable.
    struct Slot {
        /// The raw pointer to allocated memory, or nil if deallocated.
        private var raw: UnsafeMutableRawPointer?
        private var isInitialized: Bool = false
        private var isConsumed: Bool = false

        /// The address of the allocated memory as UInt.
        /// This is Sendable and can be captured in @Sendable closures.
        /// Reconstruct the pointer inside the closure with:
        /// `UnsafeMutableRawPointer(bitPattern: address)!`
        var address: UInt {
            guard let raw = raw else {
                preconditionFailure("Slot already deallocated")
            }
            return UInt(bitPattern: raw)
        }

        /// Allocates a slot with storage for one File.Handle.
        static func allocate() -> Slot {
            let raw = UnsafeMutableRawPointer.allocate(
                byteCount: MemoryLayout<File.Handle>.stride,
                alignment: MemoryLayout<File.Handle>.alignment
            )
            return Slot(raw: raw)
        }

        private init(raw: UnsafeMutableRawPointer) {
            self.raw = raw
        }

        /// Initializes the slot with a handle, consuming ownership.
        /// Use this when the handle is available on the actor side.
        mutating func initialize(with handle: consuming File.Handle) {
            guard let raw = raw else {
                preconditionFailure("Slot already deallocated")
            }
            precondition(!isInitialized, "Slot already initialized")
            precondition(!isConsumed, "Slot already consumed")
            isInitialized = true
            raw.initializeMemory(as: File.Handle.self, to: handle)
        }

        /// Marks the slot as initialized after memory was written via static method.
        /// Call this after `lane.run` returns successfully.
        mutating func markInitialized() {
            precondition(!isInitialized, "Slot already initialized")
            precondition(!isConsumed, "Slot already consumed")
            isInitialized = true
        }

        /// Execute a closure with inout access to the handle.
        ///
        /// **Must only be called from within the lane closure.**
        /// The `raw` pointer must be reconstructed from address inside the closure.
        static func withHandle<T, E: Swift.Error>(
            at raw: UnsafeMutableRawPointer,
            _ body: (inout File.Handle) throws(E) -> T
        ) throws(E) -> T {
            let typed = raw.assumingMemoryBound(to: File.Handle.self)
            return try body(&typed.pointee)
        }

        /// Initialize memory at the raw pointer location.
        ///
        /// **Must only be called from within the lane closure.**
        /// The `raw` pointer must be reconstructed from address inside the closure.
        static func initializeMemory(
            at raw: UnsafeMutableRawPointer,
            with handle: consuming File.Handle
        ) {
            raw.initializeMemory(as: File.Handle.self, to: handle)
        }

        /// Move the handle out of memory and close it.
        ///
        /// This is for the close path where we consume the handle entirely.
        /// **Must only be called from within the lane closure.**
        /// The `raw` pointer must be reconstructed from address inside the closure.
        static func closeHandle(at raw: UnsafeMutableRawPointer) throws(File.Handle.Error) {
            let typed = raw.assumingMemoryBound(to: File.Handle.self)
            let handle = typed.move()
            try handle.close()
        }

        /// Takes the handle out of the slot, consuming it.
        ///
        /// **Must only be called after the lane await returns and markInitialized().**
        mutating func take() -> File.Handle {
            guard let raw = raw else {
                preconditionFailure("Slot already deallocated")
            }
            precondition(isInitialized, "Slot not initialized")
            precondition(!isConsumed, "Slot already consumed")
            isConsumed = true

            let typed = raw.assumingMemoryBound(to: File.Handle.self)
            return typed.move()
        }

        /// Deallocates the slot's raw storage only. Idempotent.
        ///
        /// This does NOT deinitialize any handle. Use via `defer` to ensure
        /// raw memory is always freed. Safe to call whether or not the slot
        /// was ever initialized or consumed.
        mutating func deallocateRawOnly() {
            guard let p = raw else { return }
            raw = nil
            p.deallocate()
        }
    }
}
