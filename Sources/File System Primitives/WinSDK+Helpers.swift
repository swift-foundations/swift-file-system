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

// MARK: - Boolean Adapter

// In Swift 6.2, the WinSDK overlay has converted Windows APIs to return Swift Bool.
// WindowsBool is now an alias for Bool (not Int32), so _ok is just an identity function.

/// Identity adapter for Windows API return values.
/// In Swift 6.2+, WindowsBool is Bool, so this is just identity.
@inline(__always)
internal func _ok(_ value: Bool) -> Bool { value }

#endif
