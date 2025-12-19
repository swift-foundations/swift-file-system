//
//  WinSDK+Helpers.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 19/12/2025.
//

#if os(Windows)
import WinSDK

// MARK: - DWORD Conversion Helpers

/// Converts a DWORD value to DWORD (identity).
@inline(__always)
internal func _dword(_ value: DWORD) -> DWORD { value }

/// Converts a UInt32 value to DWORD.
/// Use for WinSDK constants that are typed as UInt32 (e.g., GENERIC_READ).
@inline(__always)
internal func _dword(_ value: UInt32) -> DWORD { DWORD(value) }

/// Converts an Int32 value to DWORD using bit-preserving conversion.
/// Use for WinSDK constants that are typed as Int32.
@inline(__always)
internal func _dword(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

// MARK: - Mask Helpers for Bitwise Operations

/// Converts a DWORD value to DWORD for mask operations (identity).
@inline(__always)
internal func _mask(_ value: DWORD) -> DWORD { value }

/// Converts a UInt32 value to DWORD for mask operations.
/// Use for WinSDK flag constants that are typed as UInt32.
@inline(__always)
internal func _mask(_ value: UInt32) -> DWORD { DWORD(value) }

/// Converts an Int32 value to DWORD for mask operations using bit-preserving conversion.
/// Use for WinSDK flag constants that are typed as Int32.
@inline(__always)
internal func _mask(_ value: Int32) -> DWORD { DWORD(bitPattern: value) }

// MARK: - Boolean Adapter

/// Converts a Bool to Bool (identity).
/// Used to normalize Windows API return types which may vary between Bool and WindowsBool.
@inline(__always)
internal func _ok(_ value: Bool) -> Bool { value }

/// Converts a WindowsBool to Bool.
/// Used to normalize Windows API return types which may vary between Bool and WindowsBool.
@inline(__always)
internal func _ok(_ value: WindowsBool) -> Bool { value.boolValue }

#endif
