//
//  WinSDK+Helpers.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 19/12/2025.
//

#if os(Windows)
public import WinSDK

/// Safely converts an Int32 constant to DWORD using bit-preserving conversion.
/// Use this for WinSDK constants that may have the high bit set (e.g., GENERIC_READ).
@inline(__always)
internal func _dword(_ value: Int32) -> DWORD {
    DWORD(bitPattern: value)
}

/// Safely converts an Int32 constant to DWORD for use in bitwise mask operations.
/// Use this when the constant is used with bitwise operators like `&` or `|`.
@inline(__always)
internal func _dwordMask(_ value: Int32) -> DWORD {
    DWORD(bitPattern: value)
}

extension WindowsBool {
    /// Converts WindowsBool to Swift Bool.
    @inline(__always)
    internal var isTrue: Bool { self != false }
}
#endif
