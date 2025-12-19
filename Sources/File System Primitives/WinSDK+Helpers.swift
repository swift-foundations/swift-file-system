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
/// Use for WinSDK constants (e.g., GENERIC_READ, FILE_SHARE_READ).
@inline(__always)
internal func _dword(_ value: UInt32) -> DWORD { value }

/// Converts an Int32 value to DWORD using bit-preserving conversion.
/// Use for WinSDK constants that may be typed as Int32.
@inline(__always)
internal func _dword(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

// MARK: - Mask Helpers for Bitwise Operations

/// Converts a UInt32/DWORD value to DWORD for mask operations.
/// Use for WinSDK flag constants.
@inline(__always)
internal func _mask(_ value: UInt32) -> DWORD { value }

/// Converts an Int32 value to DWORD for mask operations using bit-preserving conversion.
/// Use for WinSDK flag constants that may be typed as Int32.
@inline(__always)
internal func _mask(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

// MARK: - Boolean Adapter

/// Converts a WindowsBool to Bool.
/// Windows APIs return WindowsBool which needs conversion to Swift Bool.
@inline(__always)
internal func _ok(_ value: WindowsBool) -> Bool { value != 0 }

#endif
