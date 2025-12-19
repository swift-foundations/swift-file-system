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

// The Swift WinSDK overlay converts many Windows APIs to return Swift Bool,
// but some still return WindowsBool (Int32). These overloads handle both cases.

/// Identity for Swift Bool (many WinSDK APIs already return Bool in Swift 6.2+).
@inline(__always)
internal func _ok(_ value: Bool) -> Bool { value }

/// Converts WindowsBool (Int32) to Swift Bool for APIs that still use it.
@inline(__always)
internal func _ok(_ value: WindowsBool) -> Bool { value != 0 }

/// Converts Swift Bool to WindowsBool for APIs that expect it as a parameter.
@inline(__always)
internal func _winBool(_ value: Bool) -> WindowsBool { value ? 1 : 0 }

#endif
