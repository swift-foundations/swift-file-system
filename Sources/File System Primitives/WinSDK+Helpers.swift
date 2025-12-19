//
//  WinSDK+Helpers.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 19/12/2025.
//

#if os(Windows)
    import WinSDK

    // MARK: - DWORD Conversion Helpers

    // Note: On Windows, DWORD is a typealias for UInt32, so we only need one overload.
    // The Int32 overload handles constants that may be typed as signed integers.

    /// Converts a UInt32/DWORD value to DWORD.
    @inline(__always)
    internal func _dword(_ value: UInt32) -> DWORD { value }

    /// Converts an Int32 value to DWORD using bit-preserving conversion.
    @inline(__always)
    internal func _dword(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

    // MARK: - Mask Helpers for Bitwise Operations

    /// Converts a UInt32/DWORD value to DWORD for mask operations.
    @inline(__always)
    internal func _mask(_ value: UInt32) -> DWORD { value }

    /// Converts an Int32 value to DWORD for mask operations using bit-preserving conversion.
    @inline(__always)
    internal func _mask(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

    // MARK: - Boolean Adapters

    // In Swift 6.2, the WinSDK overlay has converted most Windows APIs to return Swift Bool.
    // However, some APIs still return BOOLEAN (UInt8) or WindowsBool.

    /// Identity adapter for Windows API return values that return Bool.
    @inline(__always)
    internal func _ok(_ value: Bool) -> Bool { value }

    /// Adapter for Windows APIs that return BOOLEAN (UInt8).
    /// Some APIs like CreateSymbolicLinkW still return BOOLEAN.
    @inline(__always)
    internal func _ok(_ value: BOOLEAN) -> Bool { value != 0 }

#endif
